#include "ReShade.fxh"

/* Filename: chromaticity 

   Copyright (C) 2023 W. M. Martinez
   splitted and adjusted by DariusG

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>. 
*/

/* 
SMPTE-C/170M used by NTSC and PAL and by SDTV in general.
REC709       used by HDTV in general.
SRGB         used by most webcams and computer graphics. ***NOTE***: Gamma 2.4
BT2020       used by Ultra-high definition television (UHDTV) and wide color gamut.
SMPTE240     used during the early days of HDTV (1988-1998).
NTSC1953     used by NTSC at 1953. 
EBU          used by PAL/SECAM in 1975. Identical to REC601.
*/


//               RX   RY      GX     GY     BX      BY      RL    GL    BL     TR0    TR   TR2
// SMPTE C  0.630 0.340 / 0.310 0.595 / 0.155   0.070 / 0.299 0.587 0.114 / 0.018 0.099 4.5
// REC709   0.640 0.330 / 0.300 0.600 / 0.150   0.060 / 0.212 0.715 0.072 / 0.018 0.099 4.5
// SRGB     0.640 0.330 / 0.300 0.600 / 0.150   0.060 / 0.299 0.587 0.114 / 0.040 0.055 12.92
// BT2020   0.708 0.292 / 0.170 0.797 / 0.131   0.046 / 0.262 0.678 0.059 / 0.059 0.099 4.5
// SMPTE240 0.630 0.340 / 0.310 0.595 / 0.155   0.070 / 0.212 0.701 0.086 / 0.091 0.111 4.0
// NTSC1953 0.670 0.330 / 0.210 0.710 / 0.140   0.080 / 0.210 0.710 0.080 / 0.081 0.099 4.5
// EBU      0.640 0.330 / 0.290 0.600 / 0.150   0.060 / 0.299 0.587 0.114 / 0.081 0.099 4.5
// SECAM    0.640 0.330 / 0.290 0.600 / 0.150   0.060 / 0.334 0.585 0.081 / 0.081 0.099 4.5

uniform float CHROMA_A_X <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
	ui_label = "Chromaticity R (X) [Chromaticity]";
> = 0.670;

uniform float CHROMA_A_Y <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
	ui_label = "Chromaticity R (Y) [Chromaticity]";
> = 0.330;

uniform float CHROMA_B_X <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
	ui_label = "Chromaticity G (X) [Chromaticity]";
> = 0.210;

uniform float CHROMA_B_Y <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
	ui_label = "Chromaticity G (Y) [Chromaticity]";
> = 0.710;

uniform float CHROMA_C_X <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
	ui_label = "Chromaticity B (X) [Chromaticity]";
> = 0.140;

uniform float CHROMA_C_Y <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
	ui_label = "Chromaticity B (Y) [Chromaticity]";
> = 0.080;

uniform float CHROMA_A_WEIGHT <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "Chromaticity R luminance weight [Chromaticity]";
> = 0.299;

uniform float CHROMA_B_WEIGHT <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "Chromaticity G luminance weight [Chromaticity]";
> = 0.587;

uniform float CHROMA_C_WEIGHT <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "Chromaticity B luminance weight [Chromaticity]";
> = 0.114;

uniform float CRT_TR0 <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 0.2;
	ui_step = 0.001;
	ui_label = "Transfer Function (0) [Chromaticity]";
> = 0.018;

uniform float CRT_TR <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 0.2;
	ui_step = 0.001;
	ui_label = "Transfer Function (1) [Chromaticity]";
> = 0.099;

uniform float CRT_TR2 <
	ui_type = "drag";
	ui_min = 3.0;
	ui_max = 5.0;
	ui_step = 0.05;
	ui_label = "Transfer Function (2) [Chromaticity]";
> = 4.5;

uniform bool SCALE_W <
	ui_type = "bool";
	ui_label = "Scale White Point [Chromaticity]";
> = true;

uniform float GAMMAIN <
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = 4.0;
	ui_step = 0.05;
	ui_label = "Gamma In [Chromaticity]";
> = 2.4;

uniform float GAMMAOUT <
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = 4.0;
	ui_step = 0.05;
	ui_label = "Gamma Out [Chromaticity]";
> = 2.2;

static const float3 WHITE = float3(1.0, 1.0, 1.0);

static const float3x3 XYZ_TO_sRGB = float3x3(
	3.2406255, -0.9689307,  0.0557101,
    -1.5372080,  1.8758561, -0.2040211,
    -0.4986286,  0.0415175,  1.0569959);

float3x3 colorspace_rgb()
{
    return XYZ_TO_sRGB;
}


float3 xyY_to_XYZ(const float3 xyY)
{
    float x = xyY.x;
    float y = xyY.y;
    float Y = xyY.z;
    float z = 1.0 - x - y;

    return float3(Y * x / y, Y, Y * z / y);
}

float3 Yrgb_to_RGB(float3x3 toRGB, float3 W, float3 Yrgb)
{
    float3x3 xyYrgb = float3x3(CHROMA_A_X, CHROMA_A_Y, Yrgb.r,
                       CHROMA_B_X, CHROMA_B_Y, Yrgb.g,
                       CHROMA_C_X, CHROMA_C_Y, Yrgb.b);
    float3x3 XYZrgb = float3x3(xyY_to_XYZ(xyYrgb[0]),
                       xyY_to_XYZ(xyYrgb[1]),
                       xyY_to_XYZ(xyYrgb[2]));
    float3x3 RGBrgb = float3x3(mul(XYZrgb[0],toRGB),
                       mul(XYZrgb[1],toRGB),
                       mul(XYZrgb[2],toRGB));
    return float3(dot(W, float3(RGBrgb[0].r, RGBrgb[1].r, RGBrgb[2].r)),
                dot(W, float3(RGBrgb[0].g, RGBrgb[1].g, RGBrgb[2].g)),
                dot(W, float3(RGBrgb[0].b, RGBrgb[1].b, RGBrgb[2].b)));
}


float sdr_linear(const float x)
{
    return x < CRT_TR0 ? x / CRT_TR2 : pow((x + CRT_TR) / (1.0+ CRT_TR), GAMMAIN);
}

float3 sdr_linear(const float3 x)
{
    return float3(sdr_linear(x.r), sdr_linear(x.g), sdr_linear(x.b));
}

float srgb_gamma(const float x)
{
    return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1.0 / GAMMAOUT) - 0.055;
}

float3 srgb_gamma(const float3 x)
{
    return float3(srgb_gamma(x.r), srgb_gamma(x.g), srgb_gamma(x.b));
}

void PS_Chromaticity(in float4 pos : SV_POSITION, in float2 txcoord : TEXCOORD0, out float4 color : COLOR0)
{
    float3x3 toRGB = colorspace_rgb();
    float3 Yrgb = tex2D(ReShade::BackBuffer, txcoord).rgb;
    Yrgb = sdr_linear(Yrgb);
    float3 W = float3(CHROMA_A_WEIGHT, CHROMA_B_WEIGHT, CHROMA_C_WEIGHT);
    float3 RGB = Yrgb_to_RGB(toRGB, W, Yrgb);
    if (SCALE_W > 0.0) {
        float3 white = Yrgb_to_RGB(toRGB, W, WHITE);
        float G = 1.0 / max(max(white.r, white.g), white.b);

        RGB *= G;
    }
    RGB = clamp(RGB, 0.0, 1.0);
    RGB = srgb_gamma(RGB);
    color = float4(RGB, 1.0);
}

technique Chromaticity {
	pass Chromaticity_1 {
		VertexShader = PostProcessVS;
		PixelShader = PS_Chromaticity;
	}
}
