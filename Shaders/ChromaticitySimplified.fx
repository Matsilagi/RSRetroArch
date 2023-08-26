#include "ReShade.fxh"

uniform int COLOR_MODE <
	ui_type = "combo";
	ui_items = "SRGB\0SMPTE C\0REC709\0BT2020\0SMPTE240\0NTSC1953\0EBU\0";
	ui_label = "Color Mode [Cromaticity-Simplified]";
	ui_tooltip = "Change the color standard.";
> = 1;

uniform int Dx <
	ui_type = "combo";
	ui_items = "D50\0D55\0D60\0D65\0D75\0";
	ui_label = "Temperature [Cromaticity-Simplified]";
	ui_tooltip = "Change the color temperature.";
> = 1;

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


//0 SRGB     0.640 0.330 / 0.300 0.600 / 0.150  0.060 --
//1 SMPTE C  0.630 0.340 / 0.310 0.595 / 0.155  0.070 --
//2 REC709   0.640 0.330 / 0.300 0.600 / 0.150  0.060 --
//3 BT2020   0.708 0.292 / 0.170 0.797 / 0.131   0.046 --
//4 SMPTE240 0.630 0.340 / 0.310 0.595 / 0.155   0.070 --
//5 NTSC1953 0.670 0.330 / 0.210 0.710 / 0.140   0.080 
//6 EBU      0.640 0.330 / 0.290 0.600 / 0.150   0.060 --

float CHROMA_A_X, CHROMA_A_Y,CHROMA_B_X, CHROMA_B_Y, CHROMA_C_X, CHROMA_C_Y;
    if (COLOR_MODE == 0 || COLOR_MODE == 2 ) 
    {
		CHROMA_A_X=0.64;
		CHROMA_A_Y=0.33;
		CHROMA_B_X=0.3;
		CHROMA_B_Y=0.6;
		CHROMA_C_X= 0.15;
		CHROMA_C_Y= 0.06;
    }

	else if (COLOR_MODE == 1 || COLOR_MODE == 4) 
    {
		CHROMA_A_X=0.63;
		CHROMA_A_Y=0.34;
		CHROMA_B_X=0.31;
		CHROMA_B_Y=0.595;
		CHROMA_C_X= 0.155;
		CHROMA_C_Y= 0.070;
    }

	else if (COLOR_MODE == 3 ) 
    {
		CHROMA_A_X=0.708;
		CHROMA_A_Y=0.292;
		CHROMA_B_X=0.17;
		CHROMA_B_Y=0.797;
		CHROMA_C_X= 0.131;
		CHROMA_C_Y= 0.046;
    }
	
	else if (COLOR_MODE == 5 ) 
    {
		CHROMA_A_X=0.67;
		CHROMA_A_Y=0.33;
		CHROMA_B_X=0.21;
		CHROMA_B_Y=0.71;
		CHROMA_C_X= 0.14;
		CHROMA_C_Y= 0.08;
    }

	else if (COLOR_MODE == 6)
	{
		CHROMA_A_X=0.64;
		CHROMA_A_Y=0.33;
		CHROMA_B_X=0.29;
		CHROMA_B_Y=0.60;
		CHROMA_C_X= 0.15;
		CHROMA_C_Y= 0.06;   
	}

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

float3 luminance()
{
//0 SRGB     0.299 0.587 0.114
//1 SMPTE C  0.299 0.587 0.114 
//2 REC709   0.212 0.715 0.072 
//3 BT2020    0.262 0.678 0.059 
//4 SMPTE240  0.212 0.701 0.086 
//5 NTSC1953  0.299 0.587 0.114 
//6 EBU       0.299 0.587 0.114 

 float CHROMA_A_WEIGHT, CHROMA_B_WEIGHT, CHROMA_C_WEIGHT;
 if (COLOR_MODE == 0 || COLOR_MODE == 1 || 
      COLOR_MODE == 5 || COLOR_MODE == 6)
{
    CHROMA_A_WEIGHT = 0.299;
    CHROMA_B_WEIGHT = 0.587;
    CHROMA_C_WEIGHT = 0.114;
}

else if (COLOR_MODE == 2.0 || COLOR_MODE == 4.0)
{
    CHROMA_A_WEIGHT = 0.2126;
    CHROMA_B_WEIGHT = 0.7152;
    CHROMA_C_WEIGHT = 0.0722;
}

else if (COLOR_MODE == 3.0 )
{
    CHROMA_A_WEIGHT = 0.2627;
    CHROMA_B_WEIGHT = 0.678;
    CHROMA_C_WEIGHT = 0.0593;
}

    return float3(CHROMA_A_WEIGHT, CHROMA_B_WEIGHT, CHROMA_C_WEIGHT);
}

//////////////////////////////////////////////// 
/// GAMMA IN FUNCTION /////////////////////////

float sdr_linear(const float x)
{
//            RX   RY      GX     GY     BX      BY      RL    GL    BL       TR1    TR2   TR3
//0 SRGB     0.040 0.055 12.92
//1 SMPTE C  0.018 0.099 4.5
//2 REC709   0.018 0.099 4.5
//3 BT2020   0.059 0.099 4.5
//4 SMPTE240 0.091 0.111 4.0
//5 NTSC1953 0.018 0.099 4.5
//6 EBU      0.081 0.099 4.5

float CRT_TR1 ,CRT_TR2, CRT_TR3, GAMMAIN;

if (COLOR_MODE == 0)
{
    CRT_TR1 = 0.04045;
    CRT_TR2 = 0.055;
    CRT_TR3 = 12.92;
    GAMMAIN = 2.4;
}

else if (COLOR_MODE == 1 || COLOR_MODE == 2)
{
    CRT_TR1 = 0.081;
    CRT_TR2 = 0.099;
    CRT_TR3 = 4.5;
    GAMMAIN = 2.2;
}
else if (COLOR_MODE == 3 )
{
    CRT_TR1 = 0.018;
    CRT_TR2 = 0.099;
    CRT_TR3 = 4.5;
    GAMMAIN = 2.2;
}
else if (COLOR_MODE == 4 )
{
    CRT_TR1 = 0.0913;
    CRT_TR2 = 0.1115;
    CRT_TR3 = 4.0;
    GAMMAIN = 2.2;
}
else if (COLOR_MODE == 5 || COLOR_MODE == 6)
{
    CRT_TR1 = 0.081;
    CRT_TR2 = 0.099;
    CRT_TR3 = 4.5;
    GAMMAIN = 2.2;
}

    return x < CRT_TR1 ? x / CRT_TR3 : pow((x + CRT_TR2) / (1.0+ CRT_TR2), GAMMAIN);
}

float3 sdr_linear(const float3 x)
{
    return float3(sdr_linear(x.r), sdr_linear(x.g), sdr_linear(x.b));
}


//////////////////////////////////////////////// 
/// GAMMA OUT FUNCTION /////////////////////////

float srgb_gamma(const float x)
{
//0 SRGB     0.00313 0.055 12.92
//1 SMPTE C  0.018 0.099 4.5
//2 REC709   0.018 0.099 4.5
//3 BT2020   0.059 0.099 4.5
//4 SMPTE240 0.091 0.111 4.0
//5 NTSC1953 0.018 0.099 4.5
//6 EBU      0.081 0.099 4.5

float LCD_TR1 ,LCD_TR2, LCD_TR3, GAMMAOUT;

if (COLOR_MODE == 0)
{
    LCD_TR1 = 0.00313;
    LCD_TR2 = 0.055;
    LCD_TR3 = 12.92;
    GAMMAOUT = 2.4;
}

else if (COLOR_MODE == 1 || COLOR_MODE == 2)
{
    LCD_TR1 = 0.018;
    LCD_TR2 = 0.099;
    LCD_TR3 = 4.5;
    GAMMAOUT = 2.2;
}
else if (COLOR_MODE == 3 )
{
    LCD_TR1 = 0.018;
    LCD_TR2 = 0.099;
    LCD_TR3 = 4.5;
    GAMMAOUT = 2.2;
}
else if (COLOR_MODE == 4 )
{
    LCD_TR1 = 0.0228;
    LCD_TR2 = 0.1115;
    LCD_TR3 = 4.0;
    GAMMAOUT = 2.2;
}
else if (COLOR_MODE == 5 || COLOR_MODE == 6)
{
    LCD_TR1 = 0.018;
    LCD_TR2 = 0.099;
    LCD_TR3 = 4.5;
    GAMMAOUT = 2.2;
}
    return x <= LCD_TR1 ? LCD_TR3 * x : (1.0+LCD_TR2) * pow(x, 1.0 / GAMMAOUT) - LCD_TR2;
}

float3 srgb_gamma(const float3 x)
{
    return float3(srgb_gamma(x.r), srgb_gamma(x.g), srgb_gamma(x.b));
}

float3 TEMP ()
{
    if (Dx == 0.0) return float3(0.964,1.0,0.8252);
    else if (Dx == 1.0) return float3(0.95682,1.0,0.92149);
    else if (Dx == 2.0) return float3(0.95047,1.0,1.0888);
    else if (Dx == 3.0) return float3(0.94972,1.0,1.22638);
    else return float3(1.0,1.0,1.0);
}

void PS_ChromaticitySimplified(in float4 pos : SV_POSITION, in float2 txcoord : TEXCOORD0, out float4 color : COLOR0)
{
    float3x3 toRGB = colorspace_rgb();
    float3 Yrgb = tex2D(ReShade::BackBuffer, txcoord).rgb;
    Yrgb = sdr_linear(Yrgb);
    float3 W = luminance();
    float3 RGB = Yrgb_to_RGB(toRGB, W, Yrgb);
    
    RGB = clamp(RGB, 0.0, 1.0);
    RGB = srgb_gamma(RGB)*TEMP();
    color = float4(RGB, 1.0);
}

technique ChromaticitySimple {
	pass ChromaticitySimple_1 {
		VertexShader = PostProcessVS;
		PixelShader = PS_ChromaticitySimplified;
	}
}
