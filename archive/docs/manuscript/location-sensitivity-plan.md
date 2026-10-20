# Planned appendix: sensitivity to uncertain horizontal position (T10)

The manuscript evaluates pressure-to-altitude conversion at known positions. The author has now requested a small appendix through 200 km. The active, deliberately simpler pilot is specified in [T10 design](../../../docs/methods/T10/design.md), with a reproducible extraction script and predetermined station/sounding selection. The broader design below is retained as possible follow-up; terrain clearance and uncertainty-guidance lookup are outside the current pilot. No result is assumed in advance.

## Separate three questions

1. **Weather annotation:** how much does retrieved altitude change when the same observed pressure and time are combined with ERA5 surface pressure, temperature, orography and GPT3 from a displaced position?
2. **Terrain clearance:** how much additional uncertainty arises when ground elevation is obtained at that displaced position or across its uncertainty area? Keep this separate from the atmospheric calculation; a 50 km terrain mismatch can be large even if the atmospheric height changes little.
3. **Uncertainty lookup:** if a position is used only to select climate/terrain-specific error guidance, how often does displacement change the selected stratum and its stated error? This changes the uncertainty assigned to an estimate, rather than the estimate itself, and should not be reported as conversion error.

## Paired design

Use the same ground-station and radiosonde observations, times, pressure readings and fixed reference heights for central and displaced queries. Choose a deterministic, geographically balanced subset of stations with flat and mountainous terrain, the main climate classes, both hemispheres and seasonal coverage. Start with 50 km in eight bearings; expand to 10, 25 and 100 km only if needed to characterise the response. Preselect stations/times before inspecting the displacement effects and record the selection in a CSV.

For each ERA5 conversion, calculate the central-query error, displaced-query error and their paired difference. Re-query all required weather variables and orography together; changing only pressure would not represent the actual workflow. Retain the actual station/radiosonde reference height. Treat the standard atmosphere as a location-independent control.

Report two airborne quantities separately: (a) the effect on absolute pressure-derived altitude, and (b) the effect on the existing surface-referenced height metric, with the same displaced location used for the level and its reference surface. Do not allow the surface subtraction to hide a location effect when discussing absolute altitude. Leave time errors, actual balloon drift and joint geolocation-model feedback outside this first experiment.

## Appendix outputs

Provide a map of the central stations, the number of stations/times/queries and paired median change, MAE increment and p95 absolute change by formula, distance, terrain and height bin. Show directional spread rather than averaging bearings to a near-zero signed change. Retain equal-cell weighting and the original bird-height weights for comparable aggregate summaries. Report the original error alongside the added displacement effect.

A distinct terrain panel should show the elevation range within the displaced/uncertain area, with a consistent vertical datum. GeoPressureR's `path2elevation()` is a practical way to describe terrain percentiles along reconstructed paths; it does not itself give a probability distribution over positions or validate the ground beneath the bird.

If the paired altitude effect is small across the tested conditions, an appendix can support a bounded statement about 50 km annotation errors. If effects are concentrated near fronts, coasts, steep terrain or particular seasons, report those exceptions. The experiment will not establish that all geolocator position uncertainty is negligible, nor identify a universal acceptable error radius.
