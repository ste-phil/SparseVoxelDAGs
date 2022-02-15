namespace hlslpp
{
	float1::float1(const int1& i) : vec(_hlslpp_cvtepi32_ps(i.vec)) {}

	float2::float2(const int2& i) : vec(_hlslpp_cvtepi32_ps(i.vec)) {}

	float3::float3(const int3& i) : vec(_hlslpp_cvtepi32_ps(i.vec)) {}

	float4::float4(const int4& i) : vec(_hlslpp_cvtepi32_ps(i.vec)) {}

	float1::float1(const uint1& i) : vec(_hlslpp_cvtepu32_ps(i.vec)) {}

	float2::float2(const uint2& i) : vec(_hlslpp_cvtepu32_ps(i.vec)) {}

	float3::float3(const uint3& i) : vec(_hlslpp_cvtepu32_ps(i.vec)) {}

	float4::float4(const uint4& i) : vec(_hlslpp_cvtepu32_ps(i.vec)) {}

	hlslpp_inline float3x3::float3x3(const quaternion& q)
	{
		_hlslpp_quat_to_3x3_ps(q.vec, vec0, vec1, vec2);
	}

	hlslpp_inline float4x4::float4x4(const quaternion& q)
	{
#if defined(HLSLPP_SIMD_REGISTER_FLOAT8)

		n128 temp_vec0, temp_vec1, temp_vec2;

		_hlslpp_quat_to_3x3_ps(q.vec, temp_vec0, temp_vec1, temp_vec2);
		const n256 row01Mask = _hlslpp256_castsi256_ps(_hlslpp256_set_epi32(0xffffffff, 0xffffffff, 0xffffffff, 0, 0xffffffff, 0xffffffff, 0xffffffff, 0));
		const n256 row23Mask = _hlslpp256_castsi256_ps(_hlslpp256_set_epi32(0xffffffff, 0xffffffff, 0xffffffff, 0, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff));

		const n256 row01 = _hlslpp256_set128_ps(temp_vec0, temp_vec1);
		const n256 row23 = _hlslpp256_set128_ps(temp_vec2, _hlslpp_set_ps(0.0f, 0.0f, 0.0f, 1.0f));

		vec0 = _hlslpp256_and_ps(row01, row01Mask);
		vec1 = _hlslpp256_and_ps(row23, row23Mask);

#else

		_hlslpp_quat_to_3x3_ps(q.vec, vec0, vec1, vec2);
		const n128 zeroLast = _hlslpp_castsi128_ps(_hlslpp_set_epi32(0xffffffff, 0xffffffff, 0xffffffff, 0));
		vec0 = _hlslpp_and_ps(vec0, zeroLast);
		vec1 = _hlslpp_and_ps(vec1, zeroLast);
		vec2 = _hlslpp_and_ps(vec2, zeroLast);
		vec3 = _hlslpp_set_ps(0.0f, 0.0f, 0.0f, 1.0f);

#endif
	}

	//----------------
	// asfloat, asuint, asint
	//----------------
	hlslpp_inline float1 asfloat(const uint1 & v) { return (float1&)v; }
	hlslpp_inline float2 asfloat(const uint2 & v) { return (float2&)v; }
	hlslpp_inline float3 asfloat(const uint3 & v) { return (float3&)v; }
	hlslpp_inline float4 asfloat(const uint4 & v) { return (float4&)v; }

	hlslpp_inline float1 asfloat(const int1 & v) { return (float1&)v; }
	hlslpp_inline float2 asfloat(const int2 & v) { return (float2&)v; }
	hlslpp_inline float3 asfloat(const int3 & v) { return (float3&)v; }
	hlslpp_inline float4 asfloat(const int4 & v) { return (float4&)v; }

	hlslpp_inline uint1 asuint(const int1 & v) { return (uint1&)v; }
	hlslpp_inline uint2 asuint(const int2 & v) { return (uint2&)v; }
	hlslpp_inline uint3 asuint(const int3 & v) { return (uint3&)v; }
	hlslpp_inline uint4 asuint(const int4 & v) { return (uint4&)v; }

	hlslpp_inline uint1 asuint(const float1 & v) { return (uint1&)v; }
	hlslpp_inline uint2 asuint(const float2 & v) { return (uint2&)v; }
	hlslpp_inline uint3 asuint(const float3 & v) { return (uint3&)v; }
	hlslpp_inline uint4 asuint(const float4 & v) { return (uint4&)v; }

	hlslpp_inline int1 asint(const uint1 & v) { return (int1&)v; }
	hlslpp_inline int2 asint(const uint2 & v) { return (int2&)v; }
	hlslpp_inline int3 asint(const uint3 & v) { return (int3&)v; }
	hlslpp_inline int4 asint(const uint4 & v) { return (int4&)v; }

	hlslpp_inline int1 asint(const float1 & v) { return (int1&)v; }
	hlslpp_inline int2 asint(const float2 & v) { return (int2&)v; }
	hlslpp_inline int3 asint(const float3 & v) { return (int3&)v; }
	hlslpp_inline int4 asint(const float4 & v) { return (int4&)v; }
}