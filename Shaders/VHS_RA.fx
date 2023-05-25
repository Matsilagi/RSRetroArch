// VHS shader
// by hunterk
// adapted from ompuco's more AVdistortion shadertoy:
// https://www.shadertoy.com/view/XlsczN
// Ported to ReShade by Matsilagi

#include "ReShade.fxh"

uniform float wiggle <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.001;
	ui_label = "Wiggle [VHS-RA]";
> = 0.0;

uniform float smear <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.05;
	ui_label = "Chroma Smear [VHS-RA]";
> = 0.5;

uniform int FrameCount < source = "framecount"; >;

#define mod(x,y) (x-y*floor(x/y))
#define iTime mod(float(FrameCount), 7.0)

//YIQ/RGB shit
float3 rgb2yiq(float3 c){   
	return float3(
		(0.2989*c.x + 0.5959*c.y + 0.2115*c.z),
		(0.5870*c.x - 0.2744*c.y - 0.5229*c.z),
		(0.1140*c.x - 0.3216*c.y + 0.3114*c.z)
	);
}

float3 yiq2rgb(float3 c){				
	return float3(
		(1.0*c.x	+ 1.0*c.y	+ 1.0*c.z),
		(0.956*c.x	- 0.2720*c.y	- 1.1060*c.z),
		(0.6210*c.x	- 0.6474*c.y	+ 1.7046*c.z)
	);
}
        
float2 Circle(float Start, float Points, float Point) 
{
	float Rad = (3.141592 * 2.0 * (1.0 / Points)) * (Point + Start);
	//return float2(sin(Rad), cos(Rad));
		return float2(-(.3+Rad), cos(Rad));

}

float3 Blur(float2 uv, float d){
	float t = (sin(iTime*5.0+uv.y*5.0))/10.0;
    float b = 1.0;
    t=0.0;
    float2 PixelOffset=float2(d+.0005*t,0);
    
    float Start = 2.0 / 14.0;
    float2 Scale = 0.66 * 4.0 * 2.0 * PixelOffset.xy;
    
    float3 N0 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 0.0) * Scale).rgb;
    float3 N1 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 1.0) * Scale).rgb;
    float3 N2 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 2.0) * Scale).rgb;
    float3 N3 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 3.0) * Scale).rgb;
    float3 N4 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 4.0) * Scale).rgb;
    float3 N5 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 5.0) * Scale).rgb;
    float3 N6 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 6.0) * Scale).rgb;
    float3 N7 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 7.0) * Scale).rgb;
    float3 N8 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 8.0) * Scale).rgb;
    float3 N9 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 9.0) * Scale).rgb;
    float3 N10 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 10.0) * Scale).rgb;
    float3 N11 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 11.0) * Scale).rgb;
    float3 N12 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 12.0) * Scale).rgb;
    float3 N13 = tex2D(ReShade::BackBuffer, uv + Circle(Start, 14.0, 13.0) * Scale).rgb;
    float3 N14 = tex2D(ReShade::BackBuffer, uv).rgb;
    
	float4 clr = tex2D(ReShade::BackBuffer, uv);
    float W = 1.0 / 15.0;
    
    clr.rgb= 
		(N0 * W) +
		(N1 * W) +
		(N2 * W) +
		(N3 * W) +
		(N4 * W) +
		(N5 * W) +
		(N6 * W) +
		(N7 * W) +
		(N8 * W) +
		(N9 * W) +
		(N10 * W) +
		(N11 * W) +
		(N12 * W) +
		(N13 * W) +
		(N14 * W);
    return  float3(clr.xyz)*b;
}

float onOff(float a, float b, float c, float fc)
{
	return step(c, sin((fc * 0.001) + a*cos((fc * 0.001)*b)));
}

float2 jumpy(float2 uv, float fc)
{
	float2 look = uv;
	float window = 1./(1.+80.*(look.y-mod(fc/4.,1.))*(look.y-mod(fc/4.,1.)));
	look.x += 0.05 * sin(look.y*10. + fc)/20.*onOff(4.,4.,.3, fc)*(0.5+cos(fc*20.))*window;
	float vShift = (0.1*wiggle) * 0.4*onOff(2.,3.,.9, fc)*(sin(fc)*sin(fc*20.) + 
										 (0.5 + 0.1*sin(fc*200.)*cos(fc)));
	look.y = mod(look.y - 0.01 * vShift, 1.);
	return look;
}

void VHS_RA(in float4 pos : SV_POSITION, in float2 txcoord : TEXCOORD0, out float4 color : COLOR0)
{
	float d = .1-round(mod(iTime/3.0,1.0))*.1;
	float2 uv = jumpy(txcoord.xy, iTime);
	float2 uv2 = uv;

	float s = 0.0001 * wiggle * -d + 0.0001 * wiggle * sin(iTime);
   
	float e = min(.30,pow(max(0.0,cos(uv.y*4.0+.3)-.75)*(s+0.5)*1.0,3.0))*25.0;
	float r = (iTime*(2.0*s));
	uv.x += abs(r*pow(min(.003,(-uv.y+(.01*mod(iTime, 17.0))))*3.0,2.0));
    
	d = .051+abs(sin(s/4.0));
	float c = max(0.0001,.002*d) * smear;
	float2 uvo = uv;
	float4 final;
	final.xyz =Blur(uv,c+c*(uv.x));
	float y = rgb2yiq(final.xyz).r;
    
	uv.x += .01*d;
	c *= 6.0;
	final.xyz =Blur(uv,c);
	float i = rgb2yiq(final.xyz).g;
    
	uv.x += .005*d;
    
	c *= 2.50;
	final.xyz =Blur(uv,c);
	float q = rgb2yiq(final.xyz).b;
	final = float4(yiq2rgb(float3(y,i,q))-pow(s+e*2.0,3.0), 1.0);
	
	color = final;
}

technique VHS_RA {
	pass VHS_RA1 {
		VertexShader = PostProcessVS;
		PixelShader = VHS_RA;
	}
}
