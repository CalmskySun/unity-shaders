#ifndef SIN_FORWARD_LIGHT
#define SIN_FORWARD_LIGHT

#include "UnityCG.cginc"
#include "AutoLight.cginc"

//----------------------------------------------------------------------------------------------------------------------
#define GAMMA 2.2
#define INV_GAMMA 0.45

//----------------------------------------------------------------------------------------------------------------------
//FORWARDBASE
#ifdef UNITY_PASS_FORWARDBASE

    //Unity SH Light. http://docs.unity3d.com/Manual/RenderTech-ForwardRendering.html.
    //(UNITY_LIGHTMODEL_AMBIENT.rgb * 2) already included in SH ?
    #define SIN_SH_LIGHT_COORD(idx1)   half3 shLight : TEXCOORD##idx1;
    #define SIN_TRANSFER_SH_LIGHT_TO_FRAGMENT(o, wsNormal) o.shLight = ShadeSH9 (half4(wsNormal.xyz,1.0));
    #define SIN_SH_LIGHT(o, i) o.rgb += i.shLight.rgb;

//----------------------------------------------------------------------------------------------------------------------
//FORWARDADD
#elif defined(UNITY_PASS_FORWARDADD)
    #define SIN_SH_LIGHT_COORD(idx)
    #define SIN_TRANSFER_SH_LIGHT_TO_FRAGMENT(a, wsNormal)
    #define SIN_SH_LIGHT(o, i)
#endif //end UNITY_PASS_FORWARDBASE

//----------------------------------------------------------------------------------------------------------------------

#endif //end SIN_FORWARD_LIGHT