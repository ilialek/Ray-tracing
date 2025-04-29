using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using static UnityEngine.Mathf;

[ExecuteAlways, ImageEffectAllowedInSceneView]
public class RayTracingManager : MonoBehaviour
{
	[SerializeField, Range(0, 100)] int maxBounceCount = 4;
	[SerializeField, Range(0, 64)] int numberOfRaysPerPixel = 4;
	[SerializeField] int numRenderedFrames;

	[SerializeField] EnvironmentSettings environmentSettings;

	[SerializeField] bool useShaderInSceneView;
	[SerializeField] Shader rayTracingShader;
	[SerializeField] Shader blendingShader;

	Material rayTracingMaterial;
	Material blendingMaterial;
	RenderTexture resultTexture;

	ComputeBuffer sphereBuffer;

	void Start()
	{
		numRenderedFrames = 0;
	}

	void OnRenderImage(RenderTexture src, RenderTexture target)
	{
		bool isSceneCam = Camera.current.name == "SceneCamera";

		if (isSceneCam)
		{
			if (useShaderInSceneView)
			{
				InitFrame();
				Graphics.Blit(null, target, rayTracingMaterial);
			}
			else
			{
				Graphics.Blit(src, target); // Draw the unaltered camera render to the screen
			}
		}
		else
		{
			InitFrame();

			// Create copy of prev frame
			RenderTexture prevFrameCopy = RenderTexture.GetTemporary(src.width, src.height, 0, ShaderHelper.RGBA_SFloat);
			Graphics.Blit(resultTexture, prevFrameCopy);

			// Run the ray tracing shader and draw the result to a temp texture
			rayTracingMaterial.SetInt("Frame", numRenderedFrames);
			RenderTexture currentFrame = RenderTexture.GetTemporary(src.width, src.height, 0, ShaderHelper.RGBA_SFloat);
			Graphics.Blit(null, currentFrame, rayTracingMaterial);

			// Accumulate
			blendingMaterial.SetInt("_Frame", numRenderedFrames);
			blendingMaterial.SetTexture("_PrevFrame", prevFrameCopy);
			Graphics.Blit(currentFrame, resultTexture, blendingMaterial);

			// Draw result to screen
			Graphics.Blit(resultTexture, target);

			// Release temps
			RenderTexture.ReleaseTemporary(currentFrame);
			RenderTexture.ReleaseTemporary(prevFrameCopy);
			RenderTexture.ReleaseTemporary(currentFrame);

			numRenderedFrames += Application.isPlaying ? 1 : 0;
		}
	}

	void InitFrame()
	{
		// Create materials used in blits
		ShaderHelper.InitMaterial(rayTracingShader, ref rayTracingMaterial);
		ShaderHelper.InitMaterial(blendingShader, ref blendingMaterial);

		// Create result render texture
		ShaderHelper.CreateRenderTexture(ref resultTexture, Screen.width, Screen.height, FilterMode.Bilinear, ShaderHelper.RGBA_SFloat, "Result");

		// Update data
		UpdateCameraParameters(Camera.current);
		CreateSpheres();

	}

	void UpdateCameraParameters(Camera camera)
	{
		float planeHeight = camera.nearClipPlane * Tan(camera.fieldOfView * 0.5f * Deg2Rad) * 2;
		float planeWidth = planeHeight * camera.aspect;

		rayTracingMaterial.SetVector("ViewParameters", new Vector3(planeWidth, planeHeight, camera.nearClipPlane));
		rayTracingMaterial.SetMatrix("CamLocalToWorldMatrix", camera.transform.localToWorldMatrix);
	}

	void CreateSpheres()
	{
		// Create sphere data from the sphere objects in the scene
		RayTracedSphere[] sphereObjects = FindObjectsOfType<RayTracedSphere>();
		Sphere[] spheres = new Sphere[sphereObjects.Length];

		for (int i = 0; i < sphereObjects.Length; i++)
		{
			spheres[i] = new Sphere()
			{
				position = sphereObjects[i].transform.position,
				radius = sphereObjects[i].transform.localScale.x * 0.5f,
				material = sphereObjects[i].material
			};
		}

		// Create buffer containing all sphere data, and send it to the shader
		ShaderHelper.CreateStructuredBuffer(ref sphereBuffer, spheres);
		rayTracingMaterial.SetBuffer("Spheres", sphereBuffer);
		rayTracingMaterial.SetInt("NumSpheres", sphereObjects.Length);
		rayTracingMaterial.SetInt("MaxBounceCount", maxBounceCount);
		rayTracingMaterial.SetInt("NumberOfRaysPerPixel", numberOfRaysPerPixel);

		rayTracingMaterial.SetInteger("EnvironmentEnabled", environmentSettings.enabled ? 1 : 0);
		rayTracingMaterial.SetColor("SkyColourHorizon", environmentSettings.skyColourHorizon);
		rayTracingMaterial.SetColor("SkyColourZenith", environmentSettings.skyColourZenith);
		rayTracingMaterial.SetFloat("SunFocus", environmentSettings.sunFocus);
		rayTracingMaterial.SetFloat("SunIntensity", environmentSettings.sunIntensity);
	}

	void OnDisable()
	{
		ShaderHelper.Release(sphereBuffer);
		ShaderHelper.Release(resultTexture);
	}
}
