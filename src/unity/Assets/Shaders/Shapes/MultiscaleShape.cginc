
// how many samples we want in one wave. trade quality for perf.
uniform float _TexelsPerWave;
uniform float _MaxWavelength;
uniform float _ViewerAltitudeLevelAlpha;

// assumes orthographic camera. uses camera dimensions, target resolution, and texels-per-wave quality setting
// to give the min supported wavelength for the current render.
float MinWavelengthForCurrentOrthoCamera()
{
	const float cameraWidth = 2. * unity_OrthoParams.x;
	const float renderTargetRes = _ScreenParams.x;
	const float texSize = cameraWidth / renderTargetRes;
	const float minWavelength = texSize * _TexelsPerWave;
	return minWavelength;
}

bool SamplingIsAppropriate(float wavelengthInShape, out float wt)
{
	// weight for this shape to blend into target - 1 by default
	wt = 1.;

	const float minWavelength = MinWavelengthForCurrentOrthoCamera();

	const bool largeEnough = wavelengthInShape >= minWavelength;
	if (!largeEnough) return false;

	const bool smallEnough = wavelengthInShape < 2.*minWavelength;
	if (smallEnough) return true;

	const bool shapeTooBigForAllLods = wavelengthInShape > _MaxWavelength;
	if (!shapeTooBigForAllLods) return false;

	// wavelengths that are too big for the LOD hierarchy we still accumulated into the last LODs, because losing them
	// changes the shape dramatically (unlike wavelengths that are too small for LOD0, as these do not make a big difference to overall shape).

	// however simply adding large wavelengths into the biggest LOD results in a pop when camera changes altitude, when the accumulated
	// shape suddenly moves from LODx to LODy

	// to solve this, we blend large wavelengths across the last two LODs. this means they have to be evaluated twice, but the result is smooth.

	const bool notRenderingIntoLast2Lods = minWavelength * 4.01 < _MaxWavelength;
	if (notRenderingIntoLast2Lods) return false;

	const bool renderingIntoLastLod = minWavelength * 2.01 > _MaxWavelength;
	wt = renderingIntoLastLod ? _ViewerAltitudeLevelAlpha : 1. - _ViewerAltitudeLevelAlpha;

	return true;
}

// this is similar to the above code but broken out shapes that are known to be assigned to the correct LODS before render, as these do not
// need the full set of checks. a current example is gerstner waves which are assigned a layer based on their wavelength in ShapeGerstner.cs.
float ComputeSortedShapeWeight(float wavelengthInShape)
{
	const float minWavelength = MinWavelengthForCurrentOrthoCamera();

	if (wavelengthInShape < 2.*minWavelength)
	{
		// shape wavelength fits into ideal range, give weight == 1
		return 1.;
	}

	// wavelength too big for lod. if this is one of the last 2 lods, then we render into both of them and blend
	// across them. full comments above ^
	const bool renderingIntoLastLod = minWavelength * 2.01 > _MaxWavelength;
	return renderingIntoLastLod ? _ViewerAltitudeLevelAlpha : 1. - _ViewerAltitudeLevelAlpha;
}

float ComputeWaveSpeed( float wavelength )
{
	// wave speed of deep sea ocean waves: https://en.wikipedia.org/wiki/Wind_wave
	// https://en.wikipedia.org/wiki/Dispersion_(water_waves)#Wave_propagation_and_dispersion
	float g = 9.81;
	float k = 2. * 3.141593 / wavelength;
	float cp = sqrt( g / k );
	return cp;
}
