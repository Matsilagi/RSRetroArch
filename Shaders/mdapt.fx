#include "ReShade.fxh"

/*
   Merge Dithering and Pseudo Transparency Shader v2.8
   by Sp00kyFox, 2014
   Neighbor analysis via color metric and dot product of the difference vectors.
*/


static const float4 buffer_size = float4(BUFFER_WIDTH, BUFFER_HEIGHT, 1.0/BUFFER_WIDTH, 1.0/BUFFER_HEIGHT);


texture2D texMDAPTPassA {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;

	Format = RGB10A2;
};
sampler2D samplerMDAPTPassA { Texture = texMDAPTPassA; };

texture2D texMDAPTPassB {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;

	Format = RGB10A2;
};
sampler2D samplerMDAPTPassB { Texture = texMDAPTPassB; };


uniform bool MDAPTMODE  <
		ui_label   = "Monochrome Analysis";
> = false;
uniform bool VL   <
		ui_label   = "Vertical Lines";
> = false;
uniform bool CB   <
		ui_label   = "Checkerboard";
> = true;
uniform bool DEBUG   <
		ui_label   = "Debug View";
> = false;
uniform bool linear_gamma   <
		ui_label   = "Linear Gamma Blend";
> = false;
uniform float MDAPTPWR   <
		ui_label   = "Color Metric Exp";
		ui_type    = "slider";
		ui_min     = 0;
		ui_max     = 10;
		ui_step    = 0.1;
> = 2;
uniform float VL_LO   <
		ui_label   = "VL LO Thresh";
		ui_type    = "slider";
		ui_min     = 0;
		ui_max     = 10;
		ui_step    = 0.05;
> = 1.25;
uniform float VL_HI   <
		ui_label   = "VL HI Thresh";
		ui_type    = "slider";
		ui_min     = 0;
		ui_max     = 10;
		ui_step    = 0.05;
> = 1.75;
uniform float CB_LO   <
		ui_label   = "CB LO Thresh";
		ui_type    = "slider";
		ui_min     = 0;
		ui_max     = 25;
		ui_step    = 0.05;
> = 5.25;
uniform float CB_HI   <
		ui_label   = "CB HI Thresh";
		ui_type    = "slider";
		ui_min     = 0;
		ui_max     = 25;
		ui_step    = 0.05;
> = 5.75;

uniform float2 scaling_factor <
		ui_label   = "Scaling Factor XY";
		ui_type    = "drag";
		ui_min     = 0.1;
		ui_max     = 12;
		ui_step    = 0.1;
> = 1;


#define dotfix(x,y) saturate(dot(x,y))

float4 TEX(sampler2D s, float2 texcoord, float dx, float dy) {
	return tex2D(s, texcoord + float2(dx, dy) * buffer_size.zw * scaling_factor);
}

float4 TEXt0(float2 texcoord, float dx, float dy) {
	return TEX(ReShade::BackBuffer, texcoord, dx, dy);
}

float4 TEX_out(sampler2D s, float2 texcoord, float dx, float dy) {
	float2 coord = texcoord + float2(dx, dy) * buffer_size.zw * scaling_factor;
	float4 color = tex2Dlod(s, float4(coord, 0, 0));
	return lerp(color, pow(color, 2.2), linear_gamma);
}

float4 TEXt0_out(float2 texcoord, float dx, float dy){
	return TEX_out(ReShade::BackBuffer, texcoord, dx, dy);
}

// Reference: http://www.compuphase.com/cmetric.htm
float cdist(float3 A, float3 B)
{
	float3 diff = A-B;
	float  ravg = (A.x + B.x) * 0.5;

	diff *= diff * float3(2.0 + ravg, 4.0, 3.0 - ravg);
	
	return pow( smoothstep(3.0, 0.0, sqrt(diff.x + diff.y + diff.z)), MDAPTPWR );
}

bool eq(float3 A, float3 B) {
	return dot(A == B, float3(1, 1, 1));
}

#define and(x,y) min(x,y)
#define or(x,y)  max(x,y)

float and_(float a, float b){
	return min(a,b);
}

float and_(float a, float b, float c){
	return min(a, min(b,c));
}

float and_(float a, float b, float c, float d, float e, float f){
	return min(a, min(b, min(c, min(d, min(e,f)))));
}

float2 and_(float2 a, float2 b){
	return min(a,b);
}

float or_(float a, float b){
	return max(a,b);
}

float or_(float a, float b, float c, float d, float e){
	return max(a, max(b, max(c, max(d,e))));
}

float or_(float a, float b, float c, float d, float e, float f, float g, float h, float i){
	return max(a, max(b, max(c, max(d, max(e, max(f, max(g, max(h,i))))))));
}

float2 or_(float2 a, float2 b){
	return max(a,b);
}

float2 or_(float2 a, float2 b, float2 c, float2 d){
	return max(a, max(b, max(c,d)));
}

float2 sigmoid(float2 signal){
	return smoothstep(float2(VL_LO, CB_LO), float2(VL_HI, CB_HI), signal);
}



// Sampling ReShade::BackBuffer is expensive.
//   Sampling from an intermediate texture is not.
void sampleScreenPS(
	in float4 pos : SV_Position,
	in float2 texcoord : TEXCOORD0,
	
	out float4 color : SV_Target
) {
	color = tex2D(ReShade::BackBuffer, texcoord);
}

void pass0PS(
	in float4 pos : SV_Position,
	in float2 texcoord : TEXCOORD0,
	
	out float4 color : SV_Target
) {
	/*
		  U
		L C R
		  D	
	*/

	float3 C = TEX(ReShade::BackBuffer, texcoord, 0, 0).xyz;
	float3 L = TEX(ReShade::BackBuffer, texcoord, -1., 0.).xyz;
	float3 R = TEX(ReShade::BackBuffer, texcoord, 1., 0.).xyz;
	float3 U = TEX(ReShade::BackBuffer, texcoord, 0.,-1.).xyz;
	float3 D = TEX(ReShade::BackBuffer, texcoord, 0., 1.).xyz;


	float3 res;
	[branch]
	if (MDAPTMODE){
		res.x = dot((L == R) && (C != L), float3(1, 1, 1));
		res.y = dot((U == D) && (C != U), float3(1, 1, 1));
		res.z = float(bool(res.x) && bool(res.y) && dot((L == U), float3(1, 1, 1)));
	}
	else{
		float3 dCL = normalize(C-L), dCR = normalize(C-R), dCD = normalize(C-D), dCU = normalize(C-U);

		res.x = dotfix(dCL, dCR) * cdist(L,R);
		res.y = dotfix(dCU, dCD) * cdist(U,D);
		res.z = and_(res.x, res.y, dotfix(dCL, dCU) * cdist(L,U), dotfix(dCL, dCD) * cdist(L,D), dotfix(dCR, dCU) * cdist(R,U), dotfix(dCR, dCD) * cdist(R,D));
	}

   color = float4(res, 1.0);
}

void pass1PS(
	in float4 pos : SV_Position,
	in float2 texcoord : TEXCOORD0,
	
	out float4 color : SV_Target
) {
	/*
		UL U UR
		L  C R
		DL D DR
	*/

	float3 C = TEX(samplerMDAPTPassA, texcoord, 0., 0.).xyz;
	float3 L = TEX(samplerMDAPTPassA, texcoord, -1., 0.).xyz;
	float3 R = TEX(samplerMDAPTPassA, texcoord,  1., 0.).xyz;
	float3 D = TEX(samplerMDAPTPassA, texcoord,  0., 1.).xyz;
	float3 U = TEX(samplerMDAPTPassA, texcoord,  0.,-1.).xyz;

	float UL = TEX(samplerMDAPTPassA, texcoord, -1.,-1.).z;
	float UR = TEX(samplerMDAPTPassA, texcoord,  1.,-1.).z;
	float DL = TEX(samplerMDAPTPassA, texcoord, -1., 1.).z;
	float DR = TEX(samplerMDAPTPassA, texcoord,  1., 1.).z;

	// Checkerboard Pattern Completion
	float prCB = or_(C.z,
		and_(L.z, R.z, or_(U.x, D.x)),
		and_(U.z, D.z, or_(L.y, R.y)),
		and_(C.x, or_(and_(UL, UR), and_(DL, DR))),
		and_(C.y, or_(and_(UL, DL), and_(UR, DR))));
		
   color = float4(C.x, prCB, 0.0, 0.0);
}

void pass2PS(
	in float4 pos : SV_Position,
	in float2 texcoord : TEXCOORD0,
	
	out float4 color : SV_Target
) {
	/*
		NW  UUL U2 UUR NE
		ULL UL  U1 UR  URR
		L2  L1  C  R1  R2
		DLL DL  D1 DR  DRR	
		SW  DDL D2 DDR SE
	*/

	float2 C = TEX(samplerMDAPTPassA, texcoord, 0., 0.).xy;
	

	float2 hits = 0;
	
	//phase 1
	float2 L1 = TEX(samplerMDAPTPassB, texcoord, -1., 0.).xy;
	float2 R1 = TEX(samplerMDAPTPassB, texcoord,  1., 0.).xy;
	float2 U1 = TEX(samplerMDAPTPassB, texcoord,  0.,-1.).xy;
	float2 D1 = TEX(samplerMDAPTPassB, texcoord,  0., 1.).xy;

	//phase 2
	float2 L2 = and(TEX(samplerMDAPTPassB, texcoord, -2., 0.).xy, L1);
	float2 R2 = and(TEX(samplerMDAPTPassB, texcoord,  2., 0.).xy, R1);
	float2 U2 = and(TEX(samplerMDAPTPassB, texcoord,  0.,-2.).xy, U1);
	float2 D2 = and(TEX(samplerMDAPTPassB, texcoord,  0., 2.).xy, D1);
	float2 UL = and(TEX(samplerMDAPTPassB, texcoord, -1.,-1.).xy, or(L1, U1));
	float2 UR = and(TEX(samplerMDAPTPassB, texcoord,  1.,-1.).xy, or(R1, U1));
	float2 DL = and(TEX(samplerMDAPTPassB, texcoord, -1., 1.).xy, or(L1, D1));
	float2 DR = and(TEX(samplerMDAPTPassB, texcoord,  1., 1.).xy, or(R1, D1));

	//phase 3
	float2 ULL = and(TEX(samplerMDAPTPassB, texcoord, -2.,-1.).xy, or(L2, UL));
	float2 URR = and(TEX(samplerMDAPTPassB, texcoord,  2.,-1.).xy, or(R2, UR));
	float2 DRR = and(TEX(samplerMDAPTPassB, texcoord,  2., 1.).xy, or(R2, DR));
	float2 DLL = and(TEX(samplerMDAPTPassB, texcoord, -2., 1.).xy, or(L2, DL));
	float2 UUL = and(TEX(samplerMDAPTPassB, texcoord, -1.,-2.).xy, or(U2, UL));
	float2 UUR = and(TEX(samplerMDAPTPassB, texcoord,  1.,-2.).xy, or(U2, UR));
	float2 DDR = and(TEX(samplerMDAPTPassB, texcoord,  1., 2.).xy, or(D2, DR));
	float2 DDL = and(TEX(samplerMDAPTPassB, texcoord, -1., 2.).xy, or(D2, DL));

	//phase 4
	hits += and(TEX(samplerMDAPTPassB, texcoord, -2.,-2.).xy, or(UUL, ULL));
	hits += and(TEX(samplerMDAPTPassB, texcoord,  2.,-2.).xy, or(UUR, URR));
	hits += and(TEX(samplerMDAPTPassB, texcoord, -2., 2.).xy, or(DDL, DLL));
	hits += and(TEX(samplerMDAPTPassB, texcoord,  2., 2.).xy, or(DDR, DRR));

	hits += (ULL + URR + DRR + DLL + L2 + R2) + float2(0.0, 1.0) * (C + U1 + U2 + D1 + D2 + L1 + R1 + UL + UR + DL + DR + UUL + UUR + DDR + DDL);

   color = float4(C * sigmoid(hits), C);
}

void pass3PS(
	in float4 pos : SV_Position,
	in float2 texcoord : TEXCOORD0,
	
	out float4 color : SV_Target
) {
	/*
		UL U UR
		L  C R
		DL D DR
	*/

	float4 C  = TEX(samplerMDAPTPassA, texcoord,  0., 0.);
	float2 L  = TEX(samplerMDAPTPassA, texcoord, -1., 0.).xy;
	float2 R  = TEX(samplerMDAPTPassA, texcoord,  1., 0.).xy;
	float2 U  = TEX(samplerMDAPTPassA, texcoord,  0.,-1.).xy;
	float2 D  = TEX(samplerMDAPTPassA, texcoord,  0., 1.).xy;
	float UL = TEX(samplerMDAPTPassA, texcoord, -1.,-1.).y;
	float UR = TEX(samplerMDAPTPassA, texcoord,  1.,-1.).y;
	float DL = TEX(samplerMDAPTPassA, texcoord, -1., 1.).y;
	float DR = TEX(samplerMDAPTPassA, texcoord,  1., 1.).y;
	float3 c  = TEXt0(texcoord,  0., 0.).xyz;
	float3 l  = TEXt0(texcoord, -1., 0.).xyz;
	float3 r  = TEXt0(texcoord,  1., 0.).xyz;
	float3 u  = TEXt0(texcoord,  0.,-1.).xyz;
	float3 d  = TEXt0(texcoord,  0., 1.).xyz;
	float3 ul = TEXt0(texcoord, -1.,-1.).xyz;
	float3 ur = TEXt0(texcoord,  1.,-1.).xyz;
	float3 dl = TEXt0(texcoord, -1., 1.).xyz;
	float3 dr = TEXt0(texcoord,  1., 1.).xyz;

	// Backpropagation
	C.xy = or_(C.xy, and_(C.zw, or_(L, R, U, D)));

	// Checkerboard Smoothing
	C.y = or_(C.y, min(U.y, float(eq(c,u))), min(D.y, float(eq(c,d))), min(L.y, float(eq(c,l))), min(R.y, float(eq(c,r))), min(UL, float(eq(c,ul))), min(UR, float(eq(c,ur))), min(DL, float(eq(c,dl))), min(DR, float(eq(c,dr))));

   color = C;
}

void pass4PS(
	in float4 pos : SV_Position,
	in float2 texcoord : TEXCOORD0,
	
	out float4 color : SV_Target
) {
	/*
		UL U UR
		L  C R
		DL D DR	
	*/

	float4 C = TEX_out(samplerMDAPTPassB, texcoord,  0., 0.);
	float2 L = TEX_out(samplerMDAPTPassB, texcoord, -1., 0.).xy;
	float2 R = TEX_out(samplerMDAPTPassB, texcoord,  1., 0.).xy;
	float2 U = TEX_out(samplerMDAPTPassB, texcoord,  0.,-1.).xy;
	float2 D = TEX_out(samplerMDAPTPassB, texcoord,  0., 1.).xy;
	float3 c = TEXt0_out(texcoord,  0., 0.).xyz;
	float3 l = TEXt0_out(texcoord, -1., 0.).xyz;
	float3 r = TEXt0_out(texcoord,  1., 0.).xyz;

	float prVL = 0;
	float prCB = 0;
	float3 fVL = 0;
	float3 fCB = 0;


	// Backpropagation
	C.xy = or_(C.xy, and_(C.zw, or_(L.xy, R.xy, U.xy, D.xy)));

	[branch]
	if (VL) {
		float prSum = L.x + R.x;		

		prVL = max(L.x, R.x);
		prVL = (prVL == 0.0) ? 1.0 : prSum/prVL;
	
		fVL  = (prVL*c + L.x*l + R.x*r)/(prVL + prSum);
		prVL = C.x;
	}

	[branch]
	if (CB) {	
		float3 u = TEXt0_out(texcoord,  0.,-1.).xyz;
		float3 d = TEXt0_out(texcoord,  0., 1.).xyz;

		float eqCL = float(eq(c,l));
		float eqCR = float(eq(c,r));
		float eqCU = float(eq(c,u));
		float eqCD = float(eq(c,d));

		float prU = or_(U.y, eqCU);
		float prD = or_(D.y, eqCD);
		float prL = or_(L.y, eqCL);
		float prR = or_(R.y, eqCR);


		float prSum = prU  + prD  + prL  + prR;

		prCB = max(prL, max(prR, max(prU,prD)));
		prCB = (prCB == 0.0) ? 1.0 : prSum/prCB; 
		
		//standard formula: C/2 + (L + R + D + U)/8
		fCB = (prCB*c + prU*u + prD*d + prL*l + prR*r)/(prCB + prSum);


		float UL = TEX_out(samplerMDAPTPassB, texcoord, -1.,-1.).y;
		float UR = TEX_out(samplerMDAPTPassB, texcoord,  1.,-1.).y;
		float DL = TEX_out(samplerMDAPTPassB, texcoord, -1., 1.).y;
		float DR = TEX_out(samplerMDAPTPassB, texcoord,  1., 1.).y;
		float3 ul = TEXt0_out(texcoord, -1.,-1.).xyz;
		float3 ur = TEXt0_out(texcoord,  1.,-1.).xyz;
		float3 dl = TEXt0_out(texcoord, -1., 1.).xyz;
		float3 dr = TEXt0_out(texcoord,  1., 1.).xyz;

		// Checkerboard Smoothing
		prCB = or_(C.y, and_(L.y, eqCL), and_(R.y, eqCR), and_(U.y, eqCU), and_(D.y, eqCD), and_(UL, float(eq(c,ul))), and_(UR, float(eq(c,ur))), and_(DL, float(eq(c,dl))), and_(DR, float(eq(c,dr))));
	}
	
	float4 final = (prCB >= prVL) ? float4(lerp(c, fCB, prCB), 1.0) : float4(lerp(c, fVL, prVL), 1.0);
	
	color = DEBUG ? float4(prVL, prCB, 0, 0) : (
			linear_gamma ? pow(final, 1.0/2.2) : final
	);
}


technique MDAPT
{
		pass pass0
		{
			VertexShader = PostProcessVS;
			PixelShader = pass0PS;
			
			RenderTarget = texMDAPTPassA;
		}
		pass pass1
		{
			VertexShader = PostProcessVS;
			PixelShader = pass1PS;
			
			RenderTarget = texMDAPTPassB;
		}
		pass pass2
		{
			VertexShader = PostProcessVS;
			PixelShader = pass2PS;
			
			RenderTarget = texMDAPTPassA;
		}
		pass pass3
		{
			VertexShader = PostProcessVS;
			PixelShader = pass3PS;
			
			RenderTarget = texMDAPTPassB;
		}
		pass pass4
		{
			VertexShader = PostProcessVS;
			PixelShader = pass4PS;
		}
}