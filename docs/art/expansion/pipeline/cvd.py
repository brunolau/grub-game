"""Colour-vision-deficiency simulation and colour difference, for the multiplayer readability checks.

Simulation: Machado, Oliveira and Fernandes (2009), "A Physiologically-based Model for Simulation of Color Vision
Deficiency", IEEE TVCG 15(6), severity 1.0 matrices (dichromacy), applied in linear sRGB. Cross-check for the red-green
types: Vienot, Brettel and Mollon (1999) projection, the model most simulators (Color Oracle, DaltonLens "Vienot")
use for protanopia / deuteranopia. Difference: CIEDE2000 on CIELAB (D65).

Only NumPy; no third-party colour package (none is installed in the project venv, and none is needed).
"""
import numpy as np

# Machado 2009, severity 1.0 (rows: output R, G, B; columns: input linear R, G, B)
MACHADO = {
    "protan": np.array([[0.152286, 1.052583, -0.204868],
                        [0.114503, 0.786281, 0.099216],
                        [-0.003882, -0.048116, 1.051998]]),
    "deutan": np.array([[0.367322, 0.860646, -0.227968],
                        [0.280085, 0.672501, 0.047413],
                        [-0.011820, 0.042940, 0.968881]]),
    "tritan": np.array([[1.255528, -0.076749, -0.178779],
                        [-0.078411, 0.930809, 0.147602],
                        [0.004733, 0.691367, 0.303900]]),
}

# Vienot 1999 (via LMS, Smith-Pokorny cone fundamentals as in Color Oracle / DaltonLens)
_RGB2LMS = np.array([[17.8824, 43.5161, 4.11935],
                     [3.45565, 27.1554, 3.86714],
                     [0.0299566, 0.184309, 1.46709]])
_LMS2RGB = np.linalg.inv(_RGB2LMS)
_VIENOT_LMS = {
    "protan": np.array([[0.0, 2.02344, -2.52581], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]),
    "deutan": np.array([[1.0, 0.0, 0.0], [0.494207, 0.0, 1.24827], [0.0, 0.0, 1.0]]),
}
VIENOT = {k: _LMS2RGB @ m @ _RGB2LMS for k, m in _VIENOT_LMS.items()}

KINDS = ["normal", "protan", "deutan", "tritan"]


def srgb_to_linear(c):
    c = np.asarray(c, dtype=np.float64) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055) * 255.0


def simulate(rgb, kind, model="machado"):
    """rgb: (..., 3) uint8-like sRGB -> simulated sRGB float (..., 3) in 0..255."""
    rgb = np.asarray(rgb, dtype=np.float64)
    if kind == "normal":
        return rgb
    m = (MACHADO if model == "machado" else VIENOT)[kind]
    lin = srgb_to_linear(rgb)
    out = lin @ m.T
    return linear_to_srgb(out)


def simulate_image(im, kind, model="machado"):
    """PIL RGBA image -> simulated PIL RGBA image (alpha kept)."""
    from PIL import Image
    a = np.array(im.convert("RGBA"))
    if kind == "normal":
        return Image.fromarray(a, "RGBA")
    rgb = a[..., :3].reshape(-1, 3)
    cols, inv = np.unique(rgb, axis=0, return_inverse=True)
    sim = np.rint(simulate(cols, kind, model)).astype(np.uint8)
    a[..., :3] = sim[inv.reshape(-1)].reshape(a.shape[:2] + (3,))
    return Image.fromarray(a, "RGBA")


def to_lab(rgb):
    lin = srgb_to_linear(rgb)
    m = np.array([[0.4124564, 0.3575761, 0.1804375],
                  [0.2126729, 0.7151522, 0.0721750],
                  [0.0193339, 0.1191920, 0.9503041]])
    xyz = lin @ m.T
    xyz = xyz / np.array([0.95047, 1.0, 1.08883])
    e = 216 / 24389.0
    k = 24389 / 27.0
    f = np.where(xyz > e, np.cbrt(xyz), (k * xyz + 16) / 116.0)
    L = 116 * f[..., 1] - 16
    A = 500 * (f[..., 0] - f[..., 1])
    B = 200 * (f[..., 1] - f[..., 2])
    return np.stack([L, A, B], axis=-1)


def de2000(lab1, lab2):
    """CIEDE2000 between broadcastable (..., 3) CIELAB arrays."""
    L1, a1, b1 = np.moveaxis(np.asarray(lab1, dtype=np.float64), -1, 0)
    L2, a2, b2 = np.moveaxis(np.asarray(lab2, dtype=np.float64), -1, 0)
    C1 = np.hypot(a1, b1)
    C2 = np.hypot(a2, b2)
    Cm = (C1 + C2) / 2
    G = 0.5 * (1 - np.sqrt(Cm ** 7 / (Cm ** 7 + 25.0 ** 7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p = np.degrees(np.arctan2(b1, a1p)) % 360
    h2p = np.degrees(np.arctan2(b2, a2p)) % 360
    dLp = L2 - L1
    dCp = C2p - C1p
    dh = h2p - h1p
    dh = np.where(dh > 180, dh - 360, np.where(dh < -180, dh + 360, dh))
    dh = np.where(C1p * C2p == 0, 0, dh)
    dHp = 2 * np.sqrt(C1p * C2p) * np.sin(np.radians(dh / 2))
    Lpm = (L1 + L2) / 2
    Cpm = (C1p + C2p) / 2
    hsum = h1p + h2p
    hpm = np.where(C1p * C2p == 0, hsum,
                   np.where(np.abs(h1p - h2p) <= 180, hsum / 2,
                            np.where(hsum < 360, (hsum + 360) / 2, (hsum - 360) / 2)))
    T = (1 - 0.17 * np.cos(np.radians(hpm - 30)) + 0.24 * np.cos(np.radians(2 * hpm))
         + 0.32 * np.cos(np.radians(3 * hpm + 6)) - 0.20 * np.cos(np.radians(4 * hpm - 63)))
    dtheta = 30 * np.exp(-(((hpm - 275) / 25) ** 2))
    Rc = 2 * np.sqrt(Cpm ** 7 / (Cpm ** 7 + 25.0 ** 7))
    Sl = 1 + 0.015 * (Lpm - 50) ** 2 / np.sqrt(20 + (Lpm - 50) ** 2)
    Sc = 1 + 0.045 * Cpm
    Sh = 1 + 0.015 * Cpm * T
    Rt = -np.sin(np.radians(2 * dtheta)) * Rc
    return np.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2 + Rt * (dCp / Sc) * (dHp / Sh))


def de(rgb1, rgb2, kind="normal", model="machado"):
    """CIEDE2000 between two sRGB colours as seen by `kind`."""
    return float(de2000(to_lab(simulate(rgb1, kind, model)), to_lab(simulate(rgb2, kind, model))))


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def self_test():
    # Sharma, Wu, Dalal (2005) CIEDE2000 test pairs 1, 7, 17, 25
    pairs = [((50.0, 2.6772, -79.7751), (50.0, 0.0, -82.7485), 2.0425),
             ((50.0, 0.0, 0.0), (50.0, -1.0, 2.0), 2.3669),
             ((50.0, 2.5, 0.0), (73.0, 25.0, -18.0), 27.1492),
             ((60.2574, -34.0099, 36.2677), (60.4626, -34.1751, 39.4387), 1.2644)]
    for l1, l2, want in pairs:
        got = float(de2000(np.array(l1), np.array(l2)))
        assert abs(got - want) < 1e-3, (l1, l2, got, want)
    # simulation keeps greys grey and the matrices preserve white
    for kind in ("protan", "deutan", "tritan"):
        w = simulate((255, 255, 255), kind)
        assert np.all(np.abs(w - 255) < 1.5), (kind, w)
    return True


if __name__ == "__main__":
    print("cvd self test:", self_test())
