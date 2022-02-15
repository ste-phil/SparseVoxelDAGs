﻿#include "include/traceData_color.cginc"
#include "include/tracer.cginc"

//inline int GetLeafMask(const SVONode node)
//{
//    return node.leafMask;
//}
//
//inline bool IsValidNode(const SVONode node, const int childBit)
//{
//    return node.validMask & childBit;
//}
//
//inline bool IsLeafNode(const SVONode node, const int childBit)
//{
//    int mask = GetLeafMask(node);
//    return mask & childBit;
//}
//

inline uint FetchChildAttributeOffset(StructuredBuffer<uint> data, const uint parentIndex, const int node, const int childBit)
{
    int lowerIndexLeafOctantMask = childBit - 1;
    int childIndexOffset = countbits((uint) (node & lowerIndexLeafOctantMask)) + 1;
    childIndexOffset *= 2;

    int childAttributeOffset = data[parentIndex + childIndexOffset];
    return childAttributeOffset;
}

inline int FetchChildIndex(StructuredBuffer<uint> data, const uint parentIndex, const int node, const int childBit)
{
    int lowerIndexLeafOctantMask = childBit - 1;

    //zero out all higher bits than octantId (& op) and count bits which are 0 (tells you how many octants are before this one = offset)
    int childIndexOffset = countbits((uint) (node & lowerIndexLeafOctantMask));
    childIndexOffset *= 2;
    childIndexOffset += 1;

    int childRelativePtr = data[parentIndex + childIndexOffset];
    int childIndex = parentIndex + childIndexOffset + childRelativePtr;

    return childIndex;
}

void TraceDag(inout StructuredBuffer<uint> _octreeNodes, int maxDepth, Ray ray, out TraceResult res, float projFactor)
{
    DepthData rayStack[MAX_SCALE + 1];

    float3 o = ray.origin;
    float3 d = ray.direction;

    if (abs(d.x) < 1e-4f) d.x = 1e-4f;
    if (abs(d.y) < 1e-4f) d.y = 1e-4f;
    if (abs(d.z) < 1e-4f) d.z = 1e-4f;

    // Precompute the coefficients of tx(x), ty(y), and tz(z).
    // The octree is assumed to reside at coordinates [1, 2].

    res.dT = 1.0f / -abs(d);
    res.bT = res.dT * o;

    //Perform mirroring because we dont allow the ray`s components to be positive
    int octantMask = 0;
    if (d.x > 0.0f)
    {
        octantMask ^= 4;
        res.bT.x = 3.0f * res.dT.x - res.bT.x;
    }
    if (d.y > 0.0f)
    {
        octantMask ^= 2;
        res.bT.y = 3.0f * res.dT.y - res.bT.y;
    }
    if (d.z > 0.0f)
    {
        octantMask ^= 1;
        res.bT.z = 3.0f * res.dT.z - res.bT.z;
    }

    res.minT = max(2.0f * res.dT.x - res.bT.x, max(2.0f * res.dT.y - res.bT.y, 2.0f * res.dT.z - res.bT.z));
    res.maxT = min(res.dT.x - res.bT.x, min(res.dT.y - res.bT.y, res.dT.z - res.bT.z));
    //Remove behind the camera intersections
    res.minT = max(res.minT, 0.0f);

    float maxT = res.maxT;
    float minT = res.minT;

    // t = d * x - b
    // t + b = d * x
    // (t+b)/d = x

    uint attributeIndex = 0;

    uint parentIndex = 0;
    int currentNode = 0;
    int idx = 0;
    float3 pos = 1;
    int scale = MAX_SCALE - 1;

    float scaleExp2 = 0.5f;

    //1.5f is the position of the planes of the axis
    if (1.5f * res.dT.x - res.bT.x > minT)
    {
        idx ^= 4;
        pos.x = 1.5f;
    }
    if (1.5f * res.dT.y - res.bT.y > minT)
    {
        idx ^= 2;
        pos.y = 1.5f;
    }
    if (1.5f * res.dT.z - res.bT.z > minT)
    {
        idx ^= 1;
        pos.z = 1.5f;
    }

    while (scale < MAX_SCALE)
    {
        if (currentNode == 0)
            currentNode = _octreeNodes[parentIndex];

        float3 cornerT = pos * res.dT - res.bT;

        //minium t value to corner planes
        float maxTC = min(cornerT.x, min(cornerT.y, cornerT.z));

        int childShift = idx ^ octantMask;
        int childBit = 1 << childShift;
        int isValidNode = currentNode & childBit;

        if (isValidNode != 0 && minT <= maxT)
        {
            //push

            //Terminate ray if it is small enough
            if (scaleExp2 * projFactor > minT)
            {
                res.t = minT;
                break;
            }

            //Set the max t of the current voxel clamped to maxT (maxT is the max t value of the bounding voxel)
            float maxTV = min(maxT, maxTC);

            //Checks if the first intersection of the ray (res.minT = entrance distance of the voxel) is before the second (maxTV = exit distance of the voxel)
            if (minT <= maxTV)
            {
                int childIndex = FetchChildIndex(_octreeNodes, parentIndex, currentNode, childBit);
                int attOffset = FetchChildAttributeOffset(_octreeNodes, parentIndex, currentNode, childBit);

                bool isLeafNode = scale == (MAX_SCALE - maxDepth);

                //bool isLeafNode = childNode == 0;
                if (isLeafNode)
                {
                    //leaf node found
                    //Return minT here 
                    res.t = minT;
                    res.colorIndex = attributeIndex + attOffset;

                    break;
                }

                rayStack[scale].offset = parentIndex;
                rayStack[scale].maxT = maxT;
                rayStack[scale].attributeIndex = attributeIndex;

                float halfScale = scaleExp2 * 0.5f;
                float3 centerT = halfScale * res.dT + cornerT;

                //Set parent to next child
                parentIndex = childIndex;
                attributeIndex += attOffset;

                //Reset current node so that it will be fetched again at the start of the loop
                currentNode = 0;

                idx = 0;
                scale--;
                scaleExp2 = halfScale;

                //find octant of next child which the ray enters first
                if (centerT.x > minT)
                {
                    idx ^= 4;
                    pos.x += scaleExp2;
                }
                if (centerT.y > minT)
                {
                    idx ^= 2;
                    pos.y += scaleExp2;
                }
                if (centerT.z > minT)
                {
                    idx ^= 1;
                    pos.z += scaleExp2;
                }

                maxT = maxTV;
                currentNode = 0;

                continue;
            }
        }

        //Advance in octants of this parent

        int stepMask = 0;
        if (cornerT.x <= maxTC)
        {
            stepMask ^= 4;
            pos.x -= scaleExp2;
        }
        if (cornerT.y <= maxTC)
        {
            stepMask ^= 2;
            pos.y -= scaleExp2;
        }
        if (cornerT.z <= maxTC)
        {
            stepMask ^= 1;
            pos.z -= scaleExp2;
        }

        minT = maxTC;
        idx ^= stepMask;

        if ((idx & stepMask) != 0)
        {
            //Pop
            //Move one level up

            //Bits of IEEE float Exponent used to determine 
            uint differingBits = 0;
            if ((stepMask & 4) != 0) differingBits |= asint(pos.x) ^ asint(pos.x + scaleExp2);
            if ((stepMask & 2) != 0) differingBits |= asint(pos.y) ^ asint(pos.y + scaleExp2);
            if ((stepMask & 1) != 0) differingBits |= asint(pos.z) ^ asint(pos.z + scaleExp2);

            

            //shift right 23 to remove mantisse bits
            scale = (asint((float)differingBits) >> 23) - 127;
            scaleExp2 = asfloat((scale - MAX_SCALE + 127) << 23);

            parentIndex = rayStack[scale].offset;
            maxT = rayStack[scale].maxT;
            attributeIndex = rayStack[scale].attributeIndex;

            int3 sh = asint(pos) >> scale;
            pos = asfloat(sh << scale);
            idx = ((sh.x & 1) << 2) | ((sh.y & 1) << 1) | (sh.z & 1);

            currentNode = 0;
        }
    }

    //Not hit anything
    if (scale >= MAX_SCALE) {
        res.t = 2.0f;
        res.hitPos = 0.0f;
        return;
    }

    //Undo mirroring
    if ((octantMask & 4) != 0) pos.x = 3.0f - scaleExp2 - pos.x;
    if ((octantMask & 2) != 0) pos.y = 3.0f - scaleExp2 - pos.y;
    if ((octantMask & 1) != 0) pos.z = 3.0f - scaleExp2 - pos.z;

    const float epsilon = exp2(-MAX_SCALE);
    res.hitPos.x = min(max(ray.origin.x + res.t * ray.direction.x, pos.x + epsilon), pos.x + scaleExp2 - epsilon);
    res.hitPos.y = min(max(ray.origin.y + res.t * ray.direction.y, pos.y + epsilon), pos.y + scaleExp2 - epsilon);
    res.hitPos.z = min(max(ray.origin.z + res.t * ray.direction.z, pos.z + epsilon), pos.z + scaleExp2 - epsilon);

    res.voxelPos = pos + scaleExp2 * .5f;

}
