#include "ReShade.fxh"

#define MUL(A, B) mul(A, B)

texture XOT0_tex {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA32F;
};

sampler sXOT0 {
	Texture = XOT0_tex;
};

static const float pi = atan(1.0) * 4.0;
static const float tau = atan(1.0) * 8.0;

static const float3x3 rgb2yiq = float3x3(
	0.299, 0.596, 0.211,
	0.587,-0.274,-0.523,
	0.114,-0.322, 0.312
);

#define mod(x,y) (x-y*floor(x/y))

uniform float iTime < source = "timer"; >;

float extract_bit(float n, float b)
{
    if(b < 0.0 || b > 23.0){ return 0.0; }
	return floor(mod(floor(float(n) / exp2(floor(b))),2.0));   
}

//Complex oscillator, Fo = Oscillator freq., Fs = Sample freq., n = Sample index
float2 Oscillator(float Fo, float Fs, float N) {
	float phase = (tau * Fo * floor(N)) / Fs;
	return float2(cos(phase), sin(phase));
}

float PS_NTSCXOT_Modulate(
	float4 pos : SV_POSITION,
	float2 uv : TEXCOORD
) : SV_TARGET {
	float Fs = BUFFER_WIDTH;
	float Fcol = Fs * (1.0 / 4.0);
	float n = floor(uv.x * BUFFER_WIDTH);

	float3 cRGB = tex2D(ReShade::BackBuffer, uv).rgb;
	float3 cYIQ = mul(rgb2yiq, cRGB);

	float2 cOsc = Oscillator(Fcol, Fs, n);

	float sig = cYIQ.x + dot(cOsc, cYIQ.yz);

	return sig;
}

void PS_NTSCXOT_Modulate2(in float pos: SV_POSITION, in float2 txcoord: TEXCOORD0, out float4 col : COLOR0)
{
	float2 frgCoord = txcoord * ReShade::ScreenSize; //this is because the original shader uses OpenGL's fragCoord, which is in texels rather than pixels
    float2 cen = floor(ReShade::ScreenSize.xy / 4.0 / 2.0);
    float2 uv = floor(frgCoord.xy / 4.0);
    
    float2 offs = float2(0.0,0.0);
    float t = iTime*0.001;
    
    float idx = 0.0;
    
    offs = 20.0*float2(cos(1.1 * t), sin(1.1 * t)) + cen;
    idx = sin(pi * length(uv - offs) * 0.05);
    
    offs = 30.0*float2(cos(-2.0 * t), sin(-2.3 * t)) + cen;
    idx += sin(pi * length(uv - offs) * 0.08);
    
    offs = 40.0*float2(cos(0.3 * t), sin(0.9 * t)) + cen;
    idx += sin(pi * length(uv - offs) * 0.07);
    
    idx /= 3.0;
    
    idx = idx * 0.5 + 0.5;
    idx *= 15.5;
    idx = mod(floor(idx), 16.0);
    
    float bit = mod(floor(frgCoord.x), 4.0);
    
    col = float4(float3(extract_bit(idx, bit),extract_bit(idx, bit),extract_bit(idx, bit)), 1.0);
}

void PS_NTSCXOT_AppleSignal(in float pos: SV_POSITION, in float2 txcoord: TEXCOORD0, out float4 col : COLOR0)
{
    float2 frgCoord = txcoord * ReShade::ScreenSize; //this is because the original shader uses OpenGL's fragCoord, which is in texels rather than pixels
    float pixel = floor(frgCoord.x);
    float value = floor(16.0 * frgCoord.x / ReShade::ScreenSize.x);
    float power = exp2(mod(pixel, 4.0));
    float bitvalue = step(power, mod(value, 2.0 * power));

    col = float4(float3(bitvalue,bitvalue,bitvalue), 1.0);
}

//NTSC XOT
#define PI   3.14159265358979323846
#define TAU  6.28318530717958647693

//  TV adjustments
static const float SAT = 1.0;      //  Saturation / "Color" (normally 1.0)
static const float HUE = 0.0;      //  Hue / "Tint" (normally 0.0)
static const float BRI = 1.0;      //  Brightness (normally 1.0)

//  Filter parameters
static const int   N   = 15;       //  Filter Width
static const int   M   = (N-1)/2;	//  Filter Middle
static const float FC  = 0.25;     //  Frequency Cutoff
static const float SCF = 0.25;     //  Subcarrier Frequenc

static const float3x3 YIQ2RGB = float3x3(1.000, 1.000, 1.000,
                          0.956,-0.272,-1.106,
                          0.621,-0.647, 1.703);

float3 adjust(float3 YIQ, float H, float S, float B) {
    float3x3 M = float3x3(  B,      0.0,      0.0,
                  0.0, S*cos(H),  -sin(H), 
                  0.0,   sin(H), S*cos(H) );
    return mul(M,YIQ);
}

float sinc(float x) {
    if (x == 0.0) return 1.0;
	return sin(PI*x) / (PI*x);
}

//	Hann windowing function
float hann(float n, float N) {
    return 0.5 * (1.0 - cos((TAU*n)/(N-1.0)));
}

float pulse(float a, float b, float x) {
    return step(a, x) * step(x, b);
}

void PS_NTSCXOT(in float pos: SV_POSITION, in float2 txcoord: TEXCOORD0, out float4 col : COLOR0)
{
	float2 size = ReShade::ScreenSize.xy;
	float2 uv = txcoord.xy;
    
	    //  Compute sampling weights
    	float weights[N];
    	float sum = 0.0;
		
    	for (int n=0; n<N; n++) {
        	weights[n] = hann(float(n), float(N)) * sinc(FC * float(n-M));
        	sum += weights[n];
    	}
        
        //  Normalize sampling weights
        for (int n=0; n<N; n++) {
            weights[n] /= sum;
        }
        
        //	Sample composite signal and decode to YIQ
        float3 YIQ = float3(0.0,0.0,0.0);
        for (int n=0; n<N; n++) {
            float2 pos = uv + float2(float(n-M) / size.x, 0.0);
	        float phase = TAU * (SCF * size.x * pos.x);
			YIQ += float3(1.0, cos(phase), sin(phase)) * tex2D(ReShade::BackBuffer, pos).rgb * weights[n];
        }
        
        //  Apply TV adjustments to YIQ signal and convert to RGB
        col = float4(mul(YIQ2RGB,adjust(YIQ, HUE, SAT, BRI)), 1.0);

}

technique NTSCXOT_Modulator
{
   	pass NTSCXOT_Modulate
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_NTSCXOT_Modulate;
		RenderTarget = XOT0_tex;
	}
}

technique NTSCXOT_Modulator2
{
	pass NTSCXOT_Modulate2
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_NTSCXOT_Modulate2;
		RenderTarget = XOT0_tex;
	}
}

technique NTSCXOT_Modulator3
{
	pass NTSCXOT_Modulate3
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_NTSCXOT_AppleSignal;
		RenderTarget = XOT0_tex;
	}
}

technique NTSC_XOT
{
   pass NTSCXOT {
	 VertexShader = PostProcessVS;
	 PixelShader = PS_NTSCXOT;
   }
}