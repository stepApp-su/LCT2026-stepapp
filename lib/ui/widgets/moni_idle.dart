import 'dart:math' as math;

const moniIdleSeconds = 12;

// Whole cycles keep both position and velocity continuous at the loop seam.
double moniIdleWave(double seconds, int cycles) =>
    math.sin(seconds / moniIdleSeconds * 2 * math.pi * cycles);
