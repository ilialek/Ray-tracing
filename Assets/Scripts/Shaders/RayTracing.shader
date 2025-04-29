Shader "Unlit/RayTracing"
{
    Properties
    {
        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            int MaxBounceCount;
            int NumberOfRaysPerPixel;
            int Frame;

            // Environment Settings
			int EnvironmentEnabled;
			float4 SkyColourHorizon;
			float4 SkyColourZenith;
			float SunFocus;
			float SunIntensity;

            float3 ViewParameters;
			float4x4 CamLocalToWorldMatrix;

            struct Ray
			{
				float3 origin;
				float3 dir;
			};

            struct RayTracingMaterial
			{
				float4 color;
                float4 emissionColor;
                float emissionStrength;
                float smoothness;
			};

            struct Sphere
			{
				float3 position;
                float radius;
                RayTracingMaterial material;
			};

            struct HitInfo
			{
				bool didHit;
                float dst;
				float3 hitPoint;
                float3 normal;
                RayTracingMaterial material;
			};

            StructuredBuffer<Sphere> Spheres;
			int NumSpheres;

            HitInfo RaySphere(Ray ray, float3 sphereCentre, float sphereRadius)
            {
                HitInfo hitInfo = (HitInfo)0;
                float3 offsetRayOrigin = ray.origin - sphereCentre;

                float a = dot(ray.dir, ray.dir); // a = 1 (assuming unit vector)
				float b = 2 * dot(offsetRayOrigin, ray.dir);
				float c = dot(offsetRayOrigin, offsetRayOrigin) - sphereRadius * sphereRadius;
				// Quadratic discriminant
				float discriminant = b * b - 4 * a * c;

                if (discriminant >= 0) {
					// Distance to nearest intersection point (from quadratic formula)
					float dst = (-b - sqrt(discriminant)) / (2 * a);

					// Ignore intersections that occur behind the ray
					if (dst >= 0) {
						hitInfo.didHit = true;
						hitInfo.dst = dst;
						hitInfo.hitPoint = ray.origin + ray.dir * dst;
						hitInfo.normal = normalize(hitInfo.hitPoint - sphereCentre);
					}
				}
				return hitInfo;
            }

            // PCG (permuted congruential generator). Thanks to:
			// www.pcg-random.org and www.shadertoy.com/view/XlGcRh
			uint NextRandom(inout uint state)
			{
				state = state * 747796405 + 2891336453;
				uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
				result = (result >> 22) ^ result;
				return result;
			}

			float RandomValue(inout uint state)
			{
				return NextRandom(state) / 4294967295.0; // 2^32 - 1
			}

            // Random value in normal distribution (with mean=0 and sd=1)
			float RandomValueNormalDistribution(inout uint state)
			{
				// Thanks to https://stackoverflow.com/a/6178290
				float theta = 2 * 3.1415926 * RandomValue(state);
				float rho = sqrt(-2 * log(RandomValue(state)));
				return rho * cos(theta);
			}

			// Calculate a random direction
			float3 RandomDirection(inout uint state)
			{
				// Thanks to https://math.stackexchange.com/a/1585996
				float x = RandomValueNormalDistribution(state);
				float y = RandomValueNormalDistribution(state);
				float z = RandomValueNormalDistribution(state);
				return normalize(float3(x, y, z));
			}

            float3 RandomHemisphereDirection(float3 normal, inout uint rngState)
            {
                float3 dir = RandomDirection(rngState);
                return dir * sign(dot(normal, dir));
            }

            // Crude sky colour function for background light
			float3 GetEnvironmentLight(Ray ray)
			{
				if (!EnvironmentEnabled) {
					return 0;
				}
				
				float skyGradientT = pow(smoothstep(0, 0.4, ray.dir.y), 0.35);
				float groundToSkyT = smoothstep(-0.01, 0, ray.dir.y);
				float3 skyGradient = lerp(SkyColourHorizon, SkyColourZenith, skyGradientT);
				float sun = pow(max(0, dot(ray.dir, _WorldSpaceLightPos0.xyz)), SunFocus) * SunIntensity;
				// Combine ground, sky, and sun
				float3 composite = skyGradient + sun * (groundToSkyT>=1);
				return composite;
			}

            HitInfo CalculateRayCollision(Ray ray)
            {
                HitInfo closestHit = (HitInfo)0;

                closestHit.dst = 1.#INF;

                for (int i = 0; i < NumSpheres; i ++)
				{
					Sphere sphere = Spheres[i];
					HitInfo hitInfo = RaySphere(ray, sphere.position, sphere.radius);

					if (hitInfo.didHit && hitInfo.dst < closestHit.dst)
					{
						closestHit = hitInfo;
						closestHit.material = sphere.material;
					}
				}

                return closestHit;
            } 

            float3 Trace(Ray ray, inout uint rngState)
            {
                float3 incomingLight = 0;
                float3 rayColor = 1;

                for(int i = 0; i <= MaxBounceCount; i++)
                {
                    HitInfo hitInfo = CalculateRayCollision(ray);
                    if (hitInfo.didHit)
                    {

                        RayTracingMaterial material = hitInfo.material;

                        ray.origin = hitInfo.hitPoint;
                        float3 diffuseDir = RandomHemisphereDirection(hitInfo.normal, rngState);
						float3 specularDir = reflect(ray.dir, hitInfo.normal);
						ray.dir = lerp(diffuseDir, specularDir, material.smoothness);

                        float3 emittedLight = material.emissionColor * material.emissionStrength;
                        float lightStrength = dot(hitInfo.normal, ray.dir);
                        incomingLight += emittedLight * rayColor;
                        rayColor *= material.color * lightStrength * 2;

                    }
                    else
                    {
                        incomingLight += GetEnvironmentLight(ray) * rayColor;
                        break;
                    }
                }

                return incomingLight;

            }

            fixed4 frag (v2f i) : SV_Target
            {

                // Create seed for random number generator
				uint2 numPixels = _ScreenParams.xy;
				uint2 pixelCoord = i.uv * numPixels;
				uint pixelIndex = pixelCoord.y * numPixels.x + pixelCoord.x;
				uint rngState = pixelIndex + Frame * 719393;

                float3 viewPointLocal = float3(i.uv - 0.5f, 1) * ViewParameters;
                float3 viewPoint = mul(CamLocalToWorldMatrix, float4(viewPointLocal, 1));

                Ray ray;
                ray.origin = _WorldSpaceCameraPos;
                ray.dir = normalize(viewPoint - ray.origin);

                float3 totalIncomingLight = 0;

                for(int rayIndex = 0; rayIndex < NumberOfRaysPerPixel; rayIndex++)
                {
                    totalIncomingLight += Trace(ray, rngState);
                }

                //float3 pixelColor = Trace(ray, rngState);
                return float4(totalIncomingLight / NumberOfRaysPerPixel, 1);
            }
            ENDCG
        }
    }
}
