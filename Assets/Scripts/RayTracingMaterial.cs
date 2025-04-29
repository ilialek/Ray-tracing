using UnityEngine;

[System.Serializable]
public struct RayTracingMaterial
{
	public Color color;
	public Color emissionColor;
	public float emissionStrength;
	[Range(0, 1)] public float smoothness;

	public void SetDefaultValues()
	{
		color = Color.white;
		emissionColor = Color.black;
		emissionStrength = 0;
		smoothness = 0;
	}
}
