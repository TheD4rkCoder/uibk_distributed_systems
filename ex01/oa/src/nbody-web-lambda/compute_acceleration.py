import numpy as np

SOFTENING = 0.04
GRAVITY = 1.0

def compute_acceleration(positions: np.ndarray, masses: np.ndarray) -> np.ndarray:
    delta = positions[:, None, :] - positions[None, :, :]
    distance_squared = np.sum(delta * delta, axis=2) + SOFTENING * SOFTENING
    inverse_distance_cubed = np.power(distance_squared, -1.5)
    np.fill_diagonal(inverse_distance_cubed, 0.0)
    weighted = inverse_distance_cubed * masses[None, :]
    return -GRAVITY * np.sum(delta * weighted[:, :, None], axis=1)