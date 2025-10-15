local toolbar =plugin:CreateToolbar ("PathFX")local mainButton =toolbar:CreateButton ("Render Lightmaps","Generate high-quality lightmaps with global illumination and soft shadows.","rbxassetid://4458901886")local Plugin =plugin local Selection =game:GetService ("Selection")local RunService =game:GetService ("RunService")local ReplicatedStorage =game:GetService ("ReplicatedStorage")local Workspace =game:GetService ("Workspace")local Lighting =game:GetService ("Lighting")local UserInputService =game:GetService ("UserInputService")local HttpService =game:GetService ("HttpService")local SETTINGS ={nx =8,ny =4,nz =8,bounceCount =3,samplesPerProbe =128,rayLength =200,energyThreshold =0.005,outputModulePrefix ="bake_",probesPerModule =512,useSelectionAsCorners =true,firstBounceWeight =0.65,indirectBounceWeight =0.35,sunDirection =Vector3 .new (0.5,-0.8,0.3).Unit,sunIntensity =3.5,sunColor =Color3 .new (1,0.95,0.85),shadowRays =3,sunAngularRadius =0.004,useStratifiedSamples =true,strata =3,softSkySamples =2,exposure =1.0,gamma =2.2,saturation =1.05,contrast =1.05,minOutputBrightness =0.06,requireHitRatio =0.25,autoSun =true,sunAzimuth =0.0,progressInterval =10,lightInfluenceRadius =12,externalLightBlend =0.5,neonIntensity =2.0,}local function
	clamp (v,a,b)return math .max (a,math .min (b,v))
end
local function
	lerp (a,b,t)return a +(b -a)*t
end
local function
	colorScale (c,s)return Color3 .new (c .R *s,c .G *s,c .B *s)
end
local function
	colorAdd (a,b)return Color3 .new (a .R +b .R,a .G +b .G,a .B +b .B)
end
local function
	colorMultiply (a,b)return Color3 .new (a .R *b .R,a .G *b .G,a .B *b .B)
end
local function
	colorClamp01 (c)return Color3 .new (clamp (c .R,0,1),clamp (c .G,0,1),clamp (c .B,0,1))
end
local function
	luminance (c)return 0.2126 *c .R +0.7152 *c .G +0.0722 *c .B
end
local function
	linearToSrgb (c)local function
		chan (x)if x <=0.0031308 then
			return 12.92 *x
		else
			return 1.055 *(x ^(1 /2.4))-0.055
		end
	end
	return Color3 .new (chan (c .R),chan (c .G),chan (c .B))
end
local function
	applyAesthetic (c)local ex =colorScale (c,SETTINGS .exposure)local mid =0.5 local contrasted =Color3 .new ((mid +(ex .R -mid)*SETTINGS .contrast),(mid +(ex .G -mid)*SETTINGS .contrast),(mid +(ex .B -mid)*SETTINGS .contrast))local y =luminance (contrasted)local satC =Color3 .new (lerp (y,contrasted .R,SETTINGS .saturation),lerp (y,contrasted .G,SETTINGS .saturation),lerp (y,contrasted .B,SETTINGS .saturation))local clamped =colorClamp01 (satC)return linearToSrgb (clamped)
end
local function
	randUnitHemisphere (normal)local u =math .random ();
	local v =math .random ();
	local r =math .sqrt (u)local theta =2 *math .pi *v local x =r *math .cos (theta);
	local y =r *math .sin (theta)local z =math .sqrt (math .max (0,1 -u))local up =math .abs (normal .Y)<0.999 and Vector3 .new (0,1,0)or Vector3 .new (1,0,0)local tangent =(normal:Cross (up)).Unit local bitangent =normal:Cross (tangent)return (tangent *x +bitangent *y +normal *z).Unit
end
local function
	randUnitHemisphereAwayFromSun (sunDir)local antiSun =-sunDir local u =math .random ();
	local v =math .random ();
	local r =math .sqrt (u)local theta =2 *math .pi *v local x =r *math .cos (theta);
	local y =r *math .sin (theta)local z =math .sqrt (math .max (0,1 -u))local up =math .abs (antiSun .Y)<0.999 and Vector3 .new (0,1,0)or Vector3 .new (1,0,0)local tangent =(antiSun:Cross (up)).Unit local bitangent =antiSun:Cross (tangent)return (tangent *x +bitangent *y +antiSun *z).Unit
end
local function
	stratifiedSampleAwayFromSun (sunDir,sx,sy,strata)local u =(sx +math .random ())/strata local v =(sy +math .random ())/strata local r =math .sqrt (u);
	local theta =2 *math .pi *v local x =r *math .cos (theta);
	local y =r *math .sin (theta)local z =math .sqrt (math .max (0,1 -u))local antiSun =-sunDir local up =math .abs (antiSun .Y)<0.999 and Vector3 .new (0,1,0)or Vector3 .new (1,0,0)local tangent =(antiSun:Cross (up)).Unit local bitangent =antiSun:Cross (tangent)return (tangent *x +bitangent *y +antiSun *z).Unit
end
local function
	sampleSoftSunVisibility (origin,rayParams)local visSum =0 for i =1,SETTINGS .shadowRays do
		local base =-SETTINGS .sunDirection local jitterAxis =Vector3 .new (math .random ()-0.5,math .random ()-0.5,math .random ()-0.5).Unit local jitterAmount =SETTINGS .sunAngularRadius *(math .random ()-0.5)*2 local jittered =(base +jitterAxis *jitterAmount).Unit local shadowRay =Workspace:Raycast (origin,jittered *SETTINGS .rayLength,rayParams)if not shadowRay then
			visSum =visSum +1
		else
			local hitPart =shadowRay .Instance if hitPart and hitPart:IsA ("BasePart")then
				visSum =visSum +(hitPart .Transparency or 0)
			else
				visSum =visSum +0
			end
		end
	end
	return visSum /SETTINGS .shadowRays
end
local function
	getSurfaceAlbedo (hit)local part =hit .Instance if not part then
		return Color3 .new (1,1,1),0.8
	end
	local transparency =(part .Transparency or 0)local color =(part:IsA ("BasePart")and part .Color)or Color3 .new (1,1,1)local albedo =1 -clamp (transparency,0,0.9)local materialFactor =1.0 if part .Material ==Enum .Material .Metal then
		materialFactor =0.6
	end
	if part .Material ==Enum .Material .Glass then
		albedo =0.15
	end
	return color,(albedo *materialFactor)
end
local function
	sampleSkyContribution (dir)local upFactor =clamp (0.5 +0.5 *dir .Y,0,1)local skyTop =Color3 .new (0.12,0.16,0.22)local skyHorizon =Color3 .new (0.18,0.20,0.24)return colorAdd (colorScale (skyHorizon,1 -upFactor),colorScale (skyTop,upFactor))
end
local function
	reflect (dir,normal)return (dir -2 *dir:Dot (normal)*normal).Unit
end
local function
	traceWithBounces (origin,dir,maxBounces,rayParams,maxDist,initialEnergy,includeSun)local energy =initialEnergy or 1.0 local firstBounceColor,indirectColors,indirectCount =nil,{},0 local currOrigin,currDir =origin,dir .Unit for bounce =1,maxBounces do
		if energy <SETTINGS .energyThreshold then
			break
		end
		local hit =Workspace:Raycast (currOrigin,currDir *maxDist,rayParams)if not hit then
			local skyColor =sampleSkyContribution (currDir)local skyContribution =colorScale (skyColor,energy *0.3)if includeSun then
				local toSunDir =-SETTINGS .sunDirection local sunAlignment =math .max (0,currDir:Dot (toSunDir))if sunAlignment >0.7 then
					local sunContribution =colorScale (SETTINGS .sunColor,energy *SETTINGS .sunIntensity *sunAlignment)skyContribution =colorAdd (skyContribution,sunContribution)
				end
			end
			if bounce ==1 then
				firstBounceColor =skyContribution
			else
				table .insert (indirectColors,skyContribution);
				indirectCount =indirectCount +1
			end
			break
		end
		local hitPos,normal =hit .Position,hit .Normal .Unit local surfColor,albedo =getSurfaceAlbedo (hit)local bounceColor =colorScale (surfColor,energy *albedo)if bounce ==1 and includeSun then
			local sunVisibility =sampleSoftSunVisibility (hitPos +normal *0.01,rayParams)if sunVisibility >0 then
				local toSunDir =-SETTINGS .sunDirection local sunDot =math .max (0,normal:Dot (toSunDir))if sunDot >0 then
					local sunLighting =colorMultiply (SETTINGS .sunColor,surfColor)sunLighting =colorScale (sunLighting,sunDot *SETTINGS .sunIntensity *sunVisibility)bounceColor =colorAdd (bounceColor,sunLighting)
				end
			end
		end
		if bounce ==1 then
			firstBounceColor =bounceColor
		else
			table .insert (indirectColors,bounceColor);
			indirectCount =indirectCount +1
		end
		local dist =(hitPos -currOrigin).Magnitude local distAtten =1 /(1 +0.05 *dist)energy =energy *distAtten local specularChance =0.12 if math .random ()<specularChance then
			currDir =reflect (currDir,normal)
		else
			currDir =randUnitHemisphere (normal)
		end
		currOrigin =hitPos +currDir *0.01 energy =energy *albedo *0.85 if bounce >2 then
			local rrProb =clamp (energy,0.05,0.95)if math .random ()>rrProb then
				break
			end
			energy =energy /rrProb
		end
	end
	local finalColor =Color3 .new (0,0,0)if firstBounceColor then
		finalColor =colorScale (firstBounceColor,SETTINGS .firstBounceWeight)
	end
	if indirectCount >0 then
		local indirectAvg =Color3 .new (0,0,0)for _,iColor in ipairs (indirectColors)do
			indirectAvg =colorAdd (indirectAvg,iColor)
		end
		indirectAvg =colorScale (indirectAvg,1 /indirectCount)finalColor =colorAdd (finalColor,colorScale (indirectAvg,SETTINGS .indirectBounceWeight))
	end
	local brightness =finalColor .R +finalColor .G +finalColor .B if brightness <0.02 then
		finalColor =colorAdd (finalColor,Color3 .new (0.02,0.02,0.025))
	end
	return finalColor,energy
end
local function
	quantizeCoord (v,minv,maxv)if maxv <=minv then
		return 0
	end
	local t =(v -minv)/(maxv -minv)t =clamp (t,0,1)return math .floor (t *65535 +0.5)
end
local function
	ensureBakeFolder ()local folder =ReplicatedStorage:FindFirstChild ("ProbeBakes")if not folder then
		folder =Instance .new ("Folder");
		folder .Name ="ProbeBakes";
		folder .Parent =ReplicatedStorage
	else
		for _,child in ipairs (folder:GetChildren ())do
			if child:IsA ("ModuleScript")and child .Name:match ("^"..SETTINGS .outputModulePrefix)then
				child:Destroy ()
			end
		end
	end
	return folder
end
local function
	buildProbePositions (minCorner,maxCorner,nx,ny,nz)local positions ={}local dx =(maxCorner .X -minCorner .X)/math .max (1,nx -1)local dy =(maxCorner .Y -minCorner .Y)/math .max (1,ny -1)local dz =(maxCorner .Z -minCorner .Z)/math .max (1,nz -1)for iz =0,nz -1 do
		for iy =0,ny -1 do
			for ix =0,nx -1 do
				local pos =Vector3 .new (minCorner .X +ix *dx,minCorner .Y +iy *dy,minCorner .Z +iz *dz)table .insert (positions,{pos =pos,ix =ix,iy =iy,iz =iz})
			end
		end
	end
	return positions,dx,dy,dz
end
local function
	gatherRegionLights (minBound,maxBound)local lights ={}local function
		inRegion (pos)return pos .X >=minBound .X -SETTINGS .lightInfluenceRadius and pos .X <=maxBound .X +SETTINGS .lightInfluenceRadius and pos .Y >=minBound .Y -SETTINGS .lightInfluenceRadius and pos .Y <=maxBound .Y +SETTINGS .lightInfluenceRadius and pos .Z >=minBound .Z -SETTINGS .lightInfluenceRadius and pos .Z <=maxBound .Z +SETTINGS .lightInfluenceRadius
	end
	for _,inst in ipairs (Workspace:GetDescendants ())do
		if inst:IsA ("PointLight")or inst:IsA ("SpotLight")or inst:IsA ("SurfaceLight")then
			local parent =inst .Parent if parent and parent:IsA ("BasePart")then
				local pos =parent .Position if inRegion (pos)then
					local range =inst .Range or (SETTINGS .lightInfluenceRadius)local brightness =inst .Brightness or 1 table .insert (lights,{type =inst .ClassName,instance =inst,pos =pos,color =inst .Color or Color3 .new (1,1,1),brightness =brightness,range =range})
				end
			end
		end
		if inst:IsA ("BasePart")and inst .Material ==Enum .Material .Neon then
			local pos =inst .Position if inRegion (pos)then
				local color =inst .Color or Color3 .new (1,1,1)local sizeMag =math .max (inst .Size .X,inst .Size .Y,inst .Size .Z)table .insert (lights,{type ="Neon",instance =inst,pos =pos,color =color,brightness =SETTINGS .neonIntensity *(1 /math .max (0.1,inst .Transparency +0.01)),range =math .max (6,sizeMag *2)})
			end
		end
	end
	return lights
end
local function
	getNearbyLightsForProbe (probePos,lightsList)local sumColor =Color3 .new (0,0,0)local sumWeight =0 local maxSingle =0 for _,light in ipairs (lightsList)do
		local dist =(light .pos -probePos).Magnitude local effective =light .range +SETTINGS .lightInfluenceRadius if dist <=effective then
			local w =(1 /(1 +dist *0.25))*(light .brightness or 1)if light .type =="SpotLight"then
				w =w *1.1
			end
			if light .type =="SurfaceLight"then
				w =w *0.9
			end
			local c =light .color or Color3 .new (1,1,1)sumColor =colorAdd (sumColor,colorScale (c,w))sumWeight =sumWeight +w if w >maxSingle then
				maxSingle =w
			end
		end
	end
	if sumWeight <=0 then
		return nil
	end
	local avg =colorScale (sumColor,1 /sumWeight)local lightPower =clamp (sumWeight /(1 +#lightsList),0,10)return avg,lightPower,maxSingle
end
local function
	bakeProbes (minBound,maxBound,nx,ny,nz,probes,settings,lightsList,progressCallback)settings =settings or SETTINGS local results ={}local rp =RaycastParams .new ();
	rp .FilterType =Enum .RaycastFilterType .Exclude;
	rp .FilterDescendantsInstances ={}local startTime =tick ()local lastUpdateTime =tick ()local rayVisualizationData ={}for i,pinfo in ipairs (probes)do
		local pos =pinfo .pos local accumColor =Color3 .new (0,0,0)local accumEnergy =0 local hitSamples =0 local totalSamples =settings .samplesPerProbe rayVisualizationData ={}if settings .useStratifiedSamples and settings .strata >1 then
			local strata =settings .strata;
			local used =0 for sx =0,strata -1 do
				for sy =0,strata -1 do
					if used >=totalSamples then
						break
					end
					local dir =stratifiedSampleAwayFromSun (settings .sunDirection,sx,sy,strata)local colorContribution,remaining =traceWithBounces (pos,dir,settings .bounceCount,rp,settings .rayLength,1.0,true)accumColor =colorAdd (accumColor,colorContribution)accumEnergy =accumEnergy +remaining if Workspace:Raycast (pos,dir *settings .rayLength,rp)then
						hitSamples =hitSamples +1
					end
					if #rayVisualizationData <20 then
						table .insert (rayVisualizationData,{direction =dir,length =settings .rayLength,color =colorContribution})
					end
					used =used +1
				end
				if used >=totalSamples then
					break
				end
			end
			for rem =1,math .max (0,totalSamples -(settings .strata *settings .strata))do
				local dir =randUnitHemisphereAwayFromSun (settings .sunDirection)local colorContribution,remaining =traceWithBounces (pos,dir,settings .bounceCount,rp,settings .rayLength,1.0,true)accumColor =colorAdd (accumColor,colorContribution)accumEnergy =accumEnergy +remaining if Workspace:Raycast (pos,dir *settings .rayLength,rp)then
					hitSamples =hitSamples +1
				end
				if #rayVisualizationData <20 then
					table .insert (rayVisualizationData,{direction =dir,length =settings .rayLength,color =colorContribution})
				end
			end
		else
			for s =1,settings .samplesPerProbe do
				local dir =randUnitHemisphereAwayFromSun (settings .sunDirection)local colorContribution,remaining =traceWithBounces (pos,dir,settings .bounceCount,rp,settings .rayLength,1.0,true)accumColor =colorAdd (accumColor,colorContribution)accumEnergy =accumEnergy +remaining if Workspace:Raycast (pos,dir *settings .rayLength,rp)then
					hitSamples =hitSamples +1
				end
				if #rayVisualizationData <20 then
					table .insert (rayVisualizationData,{direction =dir,length =settings .rayLength,color =colorContribution})
				end
			end
		end
		local avgColor =colorScale (accumColor,1 /totalSamples)local avgEnergy =accumEnergy /totalSamples local aestheticColor =applyAesthetic (avgColor)local brightness =luminance (aestheticColor)local hitRatio =hitSamples /math .max (1,totalSamples)local keep =true if hitSamples ==0 or brightness <settings .minOutputBrightness or hitRatio <settings .requireHitRatio then
			keep =false
		end
		local blendedColor =aestheticColor local lightPower =0 if lightsList and #lightsList >0 then
			local lightColor,lp,maxSingle =getNearbyLightsForProbe (pos,lightsList)if lightColor then
				local litFrac =SETTINGS .externalLightBlend blendedColor =colorAdd (colorScale (aestheticColor,1 -litFrac),colorScale (lightColor,litFrac))lightPower =lp or maxSingle or 0 blendedColor =colorClamp01 (blendedColor)
			end
		end
		if keep then
			local qx =quantizeCoord (pos .X,minBound .X,maxBound .X)local qy =quantizeCoord (pos .Y,minBound .Y,maxBound .Y)local qz =quantizeCoord (pos .Z,minBound .Z,maxBound .Z)local neighbors ={}local baseIndex =1 +(pinfo .iz *(nx *ny))+(pinfo .iy *nx)+pinfo .ix if pinfo .ix >0 then
				table .insert (neighbors,baseIndex -1)
			end
			if pinfo .ix <nx -1 then
				table .insert (neighbors,baseIndex +1)
			end
			if pinfo .iy >0 then
				table .insert (neighbors,baseIndex -nx)
			end
			if pinfo .iy <ny -1 then
				table .insert (neighbors,baseIndex +nx)
			end
			if pinfo .iz >0 then
				table .insert (neighbors,baseIndex -(nx *ny))
			end
			if pinfo .iz <nz -1 then
				table .insert (neighbors,baseIndex +(nx *ny))
			end
			table .insert (results,{qx =qx,qy =qy,qz =qz,color =blendedColor,strength =avgEnergy,neighbors =neighbors,_lightPower =lightPower,})
		end
		if tick ()-lastUpdateTime >0.1 or i ==#probes then
			local elapsed =tick ()-startTime local progress =i /#probes local eta =(elapsed /math .max (0.0001,progress))-elapsed if progressCallback then
				progressCallback (i,#probes,elapsed,eta,blendedColor,rayVisualizationData)
			end
			lastUpdateTime =tick ()RunService .Heartbeat:Wait ()
		end
	end
	return results
end
local function
	writeModules (folder,minBound,maxBound,nx,ny,nz,probeResults)local total =#probeResults if total ==0 then
		warn ("No probes qualified for output. Adjust minOutputBrightness / requireHitRatio or sampling parameters.")return 0
	end
	local perModule =SETTINGS .probesPerModule local moduleIndex =1 local written =0 while written <total do
		local chunk ={}for i =1,perModule do
			local idx =written +i if idx >total then
				break
			end
			table .insert (chunk,probeResults [idx])
		end
		if #chunk ==0 then
			break
		end
		local lines ={}table .insert (lines,"local M = {}")table .insert (lines,("M.minBound = Vector3.new(%f,%f,%f)"):format (minBound .X,minBound .Y,minBound .Z))table .insert (lines,("M.maxBound = Vector3.new(%f,%f,%f)"):format (maxBound .X,maxBound .Y,maxBound .Z))table .insert (lines,("M.nx = %d"):format (nx))table .insert (lines,("M.ny = %d"):format (ny))table .insert (lines,("M.nz = %d"):format (nz))local gridStep =math .max ((maxBound .Y -minBound .Y)/math .max (1,ny -1),1)table .insert (lines,("M.gridStep = %f"):format (gridStep))table .insert (lines,("M.count = %d"):format (#chunk))table .insert (lines,"local probes = {")for i,p in ipairs (chunk)do
			local c =p .color local r,g,b =clamp (c .R,0,1),clamp (c .G,0,1),clamp (c .B,0,1)local neighborsLua ="{"for ni,nidx in ipairs (p .neighbors)do
				neighborsLua =neighborsLua ..tostring (nidx)if ni <#p .neighbors then
					neighborsLua =neighborsLua ..","
				end
			end
			neighborsLua =neighborsLua .."}"local line =("  { qx=%d, qy=%d, qz=%d, color = Color3.new(%f,%f,%f), strength=%f, neighbors=%s },"):format (p .qx,p .qy,p .qz,r,g,b,p .strength or 0,neighborsLua)table .insert (lines,line)
		end
		table .insert (lines,"}")table .insert (lines,[[
function M.getProbe(i)
    local p = probes[i]
    if not p then return nil end
    return {
        qx = p.qx, qy = p.qy, qz = p.qz,
        color = p.color,
        strength = p.strength,
        neighbors = p.neighbors
    }
end
return M
        ]])local source =table .concat (lines,"\n")local ms =Instance .new ("ModuleScript")ms .Name =SETTINGS .outputModulePrefix ..tostring (moduleIndex)ms .Source =source ms .Parent =folder written =written +#chunk moduleIndex =moduleIndex +1
	end
	return moduleIndex -1
end
local function
	runBake (minCorner,maxCorner,nx,ny,nz,progressCallback)assert (minCorner and maxCorner,"Bounds required")if SETTINGS .autoSun then
		local clock =Lighting .ClockTime or 12 local theta =(clock /24)*2 *math .pi -math .pi /2 local az =math .rad (SETTINGS .sunAzimuth or 0)local x =math .cos (theta)*math .cos (az)local y =math .sin (theta)local z =math .cos (theta)*math .sin (az)SETTINGS .sunDirection =Vector3 .new (x,y,z).Unit local elevation =clamp (y,-1,1)local warmthT =clamp (1 -(elevation +0.1)*0.9,0,1)SETTINGS .sunColor =Color3 .new (lerp (1.0,1.0,1 -warmthT),lerp (1.0,0.90,warmthT),lerp (1.0,0.65,warmthT))
	end
	local lightsList =gatherRegionLights (minCorner,maxCorner)local probes,dx,dy,dz =buildProbePositions (minCorner,maxCorner,nx,ny,nz)print ("Total probes to bake:",#probes)local probeResults =bakeProbes (minCorner,maxCorner,nx,ny,nz,probes,SETTINGS,lightsList,function
	(current,total,elapsed,eta,probeColor,rayData)if progressCallback then
			progressCallback (current,total,elapsed,eta,probeColor,rayData)
		end
	end
	)local folder =ensureBakeFolder ()local countModules =writeModules (folder,minCorner,maxCorner,nx,ny,nz,probeResults)print (("Wrote %d modules with %d probes total."):format (countModules,#probeResults))return true,lightsList,#probeResults
end
local function
	makeLabel (parent,text,y)local lbl =Instance .new ("TextLabel",parent)lbl .Position =UDim2 .new (0,8,0,y)lbl .Size =UDim2 .new (1,-16,0,18)lbl .Text =text;
	lbl .BackgroundTransparency =1 lbl .TextColor3 =Color3 .new (1,1,1);
	lbl .TextXAlignment =Enum .TextXAlignment .Left lbl .TextSize =12 return lbl
end
local function
	createDraggableNumberInput (parent,x,y,width,labelText,minVal,maxVal,default,onChange)local container =Instance .new ("Frame",parent)container .Position =UDim2 .new (0,x,0,y)container .Size =UDim2 .new (0,width,0,40)container .BackgroundTransparency =1 local label =Instance .new ("TextLabel",container)label .Position =UDim2 .new (0,0,0,0)label .Size =UDim2 .new (0.6,0,0,18)label .Text =labelText label .BackgroundTransparency =1 label .TextColor3 =Color3 .new (1,1,1)label .TextSize =12 label .TextXAlignment =Enum .TextXAlignment .Left local valueBox =Instance .new ("TextBox",container)valueBox .Position =UDim2 .new (0.6,4,0,0)valueBox .Size =UDim2 .new (0.4,-4,0,18)valueBox .Text =string .format ("%.3f",default)valueBox .BackgroundColor3 =Color3 .fromRGB (45,45,45)valueBox .TextColor3 =Color3 .new (1,1,1)valueBox .TextSize =12 valueBox .TextXAlignment =Enum .TextXAlignment .Right local dragArea =Instance .new ("TextButton",container)dragArea .Position =UDim2 .new (0.6,4,0,0)dragArea .Size =UDim2 .new (0.4,-4,0,18)dragArea .BackgroundTransparency =1 dragArea .Text =""dragArea .AutoButtonColor =false local isDragging =false local lastMouseX =0 local currentValue =default dragArea .MouseButton1Down:Connect (function
	()isDragging =true lastMouseX =UserInputService:GetMouseLocation ().X UserInputService .MouseIcon .Visible =false
	end
	)UserInputService .InputChanged:Connect (function
	(input)if isDragging and input .UserInputType ==Enum .UserInputType .MouseMovement then
			local mouseX =input .Position .X local delta =mouseX -lastMouseX local range =maxVal -minVal local sensitivity =range /200 currentValue =clamp (currentValue +delta *sensitivity,minVal,maxVal)valueBox .Text =string .format ("%.3f",currentValue)if onChange then
				onChange (currentValue)
			end
			lastMouseX =mouseX
		end
	end
	)UserInputService .InputEnded:Connect (function
	(input)if input .UserInputType ==Enum .UserInputType .MouseButton1 then
			isDragging =false UserInputService .MouseIcon .Visible =true
		end
	end
	)valueBox .FocusLost:Connect (function
	(enterPressed)if enterPressed then
			local newValue =tonumber (valueBox .Text)if newValue then
				currentValue =clamp (newValue,minVal,maxVal)valueBox .Text =string .format ("%.3f",currentValue)if onChange then
					onChange (currentValue)
				end
			else
				valueBox .Text =string .format ("%.3f",currentValue)
			end
		end
	end
	)return {container =container,setValue =function
	(val)currentValue =clamp (val,minVal,maxVal)valueBox .Text =string .format ("%.3f",currentValue)if onChange then
			onChange (currentValue)
		end
	end
	}
end
local function
	createProgressUI ()local screenGui =Instance .new ("ScreenGui")screenGui .Name ="PathFXProgress"screenGui .ResetOnSpawn =false screenGui .ZIndexBehavior =Enum .ZIndexBehavior .Sibling local frame =Instance .new ("Frame")frame .Size =UDim2 .new (0,520,0,160)frame .Position =UDim2 .new (0.5,-260,0.5,-80)frame .BackgroundColor3 =Color3 .fromRGB (30,30,30)frame .BackgroundTransparency =0.1 frame .BorderSizePixel =0 frame .Parent =screenGui local corner =Instance .new ("UICorner")corner .CornerRadius =UDim .new (0,8)corner .Parent =frame local title =Instance .new ("TextLabel")title .Size =UDim2 .new (1,-20,0,20)title .Position =UDim2 .new (0,10,0,10)title .BackgroundTransparency =1 title .Text ="Baking Lightmaps..."title .TextColor3 =Color3 .new (1,1,1)title .TextSize =16 title .Font =Enum .Font .GothamBold title .TextXAlignment =Enum .TextXAlignment .Left title .Parent =frame local progressFrame =Instance .new ("Frame")progressFrame .Size =UDim2 .new (0.6,-20,0,20)progressFrame .Position =UDim2 .new (0,10,0,40)progressFrame .BackgroundColor3 =Color3 .fromRGB (50,50,50)progressFrame .BorderSizePixel =0 progressFrame .Parent =frame local progressFill =Instance .new ("Frame")progressFill .Size =UDim2 .new (0,0,1,0)progressFill .BackgroundColor3 =Color3 .fromRGB (70,130,180)progressFill .BorderSizePixel =0 progressFill .Parent =progressFrame local progressCorner =Instance .new ("UICorner")progressCorner .CornerRadius =UDim .new (0,4)progressCorner .Parent =progressFill local statusLabel =Instance .new ("TextLabel")statusLabel .Size =UDim2 .new (0.6,-20,0,18)statusLabel .Position =UDim2 .new (0,10,0,65)statusLabel .BackgroundTransparency =1 statusLabel .Text ="Initializing..."statusLabel .TextColor3 =Color3 .new (0.9,0.9,0.9)statusLabel .TextSize =12 statusLabel .Font =Enum .Font .Gotham statusLabel .TextXAlignment =Enum .TextXAlignment .Left statusLabel .Parent =frame local etaLabel =Instance .new ("TextLabel")etaLabel .Size =UDim2 .new (0.6,-20,0,18)etaLabel .Position =UDim2 .new (0,10,0,85)etaLabel .BackgroundTransparency =1 etaLabel .Text ="ETA: Calculating..."etaLabel .TextColor3 =Color3 .new (0.8,0.8,0.8)etaLabel .TextSize =12 etaLabel .Font =Enum .Font .Gotham etaLabel .TextXAlignment =Enum .TextXAlignment .Left etaLabel .Parent =frame local rayFrame =Instance .new ("Frame")rayFrame .Size =UDim2 .new (0.4,-20,1,-20)rayFrame .Position =UDim2 .new (0.6,10,0,10)rayFrame .BackgroundColor3 =Color3 .fromRGB (20,20,20)rayFrame .BorderSizePixel =0 rayFrame .Parent =frame local rayTitle =Instance .new ("TextLabel",rayFrame)rayTitle .Position =UDim2 .new (0,8,0,6)rayTitle .Size =UDim2 .new (1,-16,0,18)rayTitle .BackgroundTransparency =1 rayTitle .Text ="Ray Visualization"rayTitle .TextColor3 =Color3 .new (1,1,1)rayTitle .TextSize =12 rayTitle .Font =Enum .Font .GothamBold rayTitle .TextXAlignment =Enum .TextXAlignment .Left local rayCanvas =Instance .new ("Frame",rayFrame)rayCanvas .Position =UDim2 .new (0,8,0,30)rayCanvas .Size =UDim2 .new (1,-16,1,-40)rayCanvas .BackgroundTransparency =1 local sunDirectionLine =Instance .new ("Frame",rayCanvas)sunDirectionLine .Size =UDim2 .new (0,2,0,2)sunDirectionLine .BackgroundColor3 =Color3 .new (1,1,0)sunDirectionLine .AnchorPoint =Vector2 .new (0.5,0.5)sunDirectionLine .Position =UDim2 .new (0.5,0,0.5,0)local rays ={}local maxRays =20 for i =1,maxRays do
		local rayLine =Instance .new ("Frame",rayCanvas)rayLine .Size =UDim2 .new (0,1,0,1)rayLine .BackgroundColor3 =Color3 .new (1,1,1)rayLine .AnchorPoint =Vector2 .new (0,0.5)rayLine .Visible =false rays [i]=rayLine
	end
	local function
		updateRayVisualization (rayData)local sunDir =SETTINGS .sunDirection local angle =math .atan2 (sunDir .Z,sunDir .X)sunDirectionLine .Rotation =math .deg (angle)for i,rayLine in ipairs (rays)do
			if rayData [i]then
				local rayInfo =rayData [i]rayLine .Visible =true rayLine .Position =UDim2 .new (0.5,0,0.5,0)rayLine .Rotation =math .deg (math .atan2 (rayInfo .direction .Z,rayInfo .direction .X))rayLine .Size =UDim2 .new (0,rayInfo .length *0.1,0,1)rayLine .BackgroundColor3 =rayInfo .color
			else
				rayLine .Visible =false
			end
		end
	end
	screenGui .Parent =game:GetService ("CoreGui")return {gui =screenGui,progressFill =progressFill,statusLabel =statusLabel,etaLabel =etaLabel,title =title,updateRayVisualization =updateRayVisualization,rayFrame =rayFrame}
end
local function
	updateProgress (ui,current,total,elapsed,eta,color,rayData)if not ui or not ui .gui or not ui .gui .Parent then
		return
	end
	local progress =current /total ui .progressFill .Size =UDim2 .new (progress,0,1,0)ui .statusLabel .Text =string .format ("Processing probe %d of %d (%.1f%%)",current,total,progress *100)if eta >0 then
		local minutes =math .floor (eta /60)local seconds =math .floor (eta %60)ui .etaLabel .Text =string .format ("ETA: %d:%02d",minutes,seconds)
	else
		ui .etaLabel .Text ="ETA: Calculating..."
	end
	if rayData and ui .updateRayVisualization then
		ui .updateRayVisualization (rayData)
	end
end
local function
	hideProgressUI (ui)if ui and ui .gui and ui .gui .Parent then
		ui .gui:Destroy ()
	end
end
local widgetInfo =DockWidgetPluginGuiInfo .new (Enum .InitialDockState .Float,true,false,420,580,200,140)local widget =plugin:CreateDockWidgetPluginGui ("PathFXBakeDock",widgetInfo)widget .Title ="PathFX Baker"local ui =Instance .new ("Frame",widget)ui .Size =UDim2 .new (1,0,1,0);
ui .BackgroundColor3 =Color3 .fromRGB (35,35,35)makeLabel (ui,"Corner A (x,y,z) or use 'Use Selection'",6)local function
	makeTextBox (parent,default,y)local tb =Instance .new ("TextBox",parent)tb .Position =UDim2 .new (0,8,0,y);
	tb .Size =UDim2 .new (1,-16,0,24)tb .Text =default;
	tb .BackgroundColor3 =Color3 .fromRGB (45,45,45);
	tb .TextColor3 =Color3 .new (1,1,1);
	tb .TextSize =12 tb .ClearTextOnFocus =false return tb
end
local cornerABox =makeTextBox (ui,"0,0,0",28)makeLabel (ui,"Corner B (x,y,z)",56)local cornerBBox =makeTextBox (ui,"30,10,30",78)makeLabel (ui,"Grid (nx,ny,nz)",106)local gridBox =makeTextBox (ui,string .format ("%d,%d,%d",SETTINGS .nx,SETTINGS .ny,SETTINGS .nz),128)makeLabel (ui,"Samples,Bounces,RayLen",156)local perfBox =makeTextBox (ui,string .format ("%d,%d,%d",SETTINGS .samplesPerProbe,SETTINGS .bounceCount,SETTINGS .rayLength),178)makeLabel (ui,"Sun Intensity (multiplier)",206)local sunIntBox =makeTextBox (ui,"3.5",228)local sY =258 local exposureInput =createDraggableNumberInput (ui,8,sY,404,"Exposure",0.1,4.0,SETTINGS .exposure,function
(v)SETTINGS .exposure =v
end
)local gammaInput =createDraggableNumberInput (ui,8,sY +42,404,"Gamma",0.5,4.0,SETTINGS .gamma,function
(v)SETTINGS .gamma =v
end
)local satInput =createDraggableNumberInput (ui,8,sY +84,200,"Saturation",0.0,2.0,SETTINGS .saturation,function
(v)SETTINGS .saturation =v
end
)local contrastInput =createDraggableNumberInput (ui,212,sY +84,200,"Contrast",0.0,2.0,SETTINGS .contrast,function
(v)SETTINGS .contrast =v
end
)local azimuthInput =createDraggableNumberInput (ui,8,sY +126,300,"Sun Azimuth (deg)",-180,180,SETTINGS .sunAzimuth,function
(v)SETTINGS .sunAzimuth =v
end
)local autoSunToggle =Instance .new ("TextButton",ui)autoSunToggle .Position =UDim2 .new (0,320,0,sY +126)autoSunToggle .Size =UDim2 .new (0,92,0,28)autoSunToggle .Text =SETTINGS .autoSun and "Auto Sun: ON"or "Auto Sun: OFF"autoSunToggle .TextSize =12 autoSunToggle .BackgroundColor3 =SETTINGS .autoSun and Color3 .fromRGB (70,130,180)or Color3 .fromRGB (100,100,100)autoSunToggle .TextColor3 =Color3 .new (1,1,1)autoSunToggle .MouseButton1Click:Connect (function
()SETTINGS .autoSun =not SETTINGS .autoSun autoSunToggle .Text =SETTINGS .autoSun and "Auto Sun: ON"or "Auto Sun: OFF"autoSunToggle .BackgroundColor3 =SETTINGS .autoSun and Color3 .fromRGB (70,130,180)or Color3 .fromRGB (100,100,100)
end
)local bakeButton =Instance .new ("TextButton",ui)bakeButton .Position =UDim2 .new (0,8,1,-38);
bakeButton .Size =UDim2 .new (0.5,-12,0,30)bakeButton .Text ="Bake";
bakeButton .BackgroundColor3 =Color3 .fromRGB (65,180,100);
bakeButton .TextSize =14 local useSelectionButton =Instance .new ("TextButton",ui)useSelectionButton .Position =UDim2 .new (0.5,4,1,-38);
useSelectionButton .Size =UDim2 .new (0.5,-12,0,30)useSelectionButton .Text ="Use Selection";
useSelectionButton .BackgroundColor3 =Color3 .fromRGB (80,120,200);
useSelectionButton .TextSize =14 local function
	parseVec3 (txt)local a,b,c =txt:match ("([%-%.%deE]+)%s*,%s*([%-%.%deE]+)%s*,%s*([%-%.%deE]+)")if not a then
		return nil
	end
	return Vector3 .new (tonumber (a),tonumber (b),tonumber (c))
end
useSelectionButton .MouseButton1Click:Connect (function
()local sel =Selection:Get ()if #sel >=2 then
		local a =sel [1];
		local b =sel [2]if a:IsA ("BasePart")and b:IsA ("BasePart")then
			local minV =Vector3 .new (math .min (a .Position .X,b .Position .X),math .min (a .Position .Y,b .Position .Y),math .min (a .Position .Z,b .Position .Z))local maxV =Vector3 .new (math .max (a .Position .X,b .Position .X),math .max (a .Position .Y,b .Position .Y),math .max (a .Position .Z,b .Position .Z))cornerABox .Text =string .format ("%f,%f,%f",minV .X,minV .Y,minV .Z)cornerBBox .Text =string .format ("%f,%f,%f",maxV .X,maxV .Y,maxV .Z)
		else
			warn ("Select two BaseParts to use as corners.")
		end
	else
		warn ("Select two objects in Explorer to use their positions as corners.")
	end
end
)bakeButton .MouseButton1Click:Connect (function
()local minCorner =parseVec3 (cornerABox .Text)local maxCorner =parseVec3 (cornerBBox .Text)local gridTxt =gridBox .Text local gx,gy,gz =gridTxt:match ("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")local perfTxt =perfBox .Text local s,b,r =perfTxt:match ("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")local sunInt =tonumber (sunIntBox .Text)if not (minCorner and maxCorner and gx and gy and gz and s and b and r and sunInt)then
		warn ("Invalid inputs. Make sure all fields are filled and formatted.")return
	end
	SETTINGS .nx =tonumber (gx);
	SETTINGS .ny =tonumber (gy);
	SETTINGS .nz =tonumber (gz)SETTINGS .samplesPerProbe =tonumber (s);
	SETTINGS .bounceCount =tonumber (b);
	SETTINGS .rayLength =tonumber (r)SETTINGS .sunIntensity =sunInt print (("Starting bake: region %s -> %s; grid %d x %d x %d; %d samples, %d bounces"):format (tostring (minCorner),tostring (maxCorner),SETTINGS .nx,SETTINGS .ny,SETTINGS .nz,SETTINGS .samplesPerProbe,SETTINGS .bounceCount))print (("Sun auto: %s; sunAzimuth: %.1f; intensity: %.2f"):format (tostring (SETTINGS .autoSun),SETTINGS .sunAzimuth,SETTINGS .sunIntensity))local progressUI =createProgressUI ()bakeButton .Text ="Baking..."bakeButton .BackgroundColor3 =Color3 .fromRGB (100,100,100)bakeButton .Active =false spawn (function
	()local ok,err,lightsList,probeCount =pcall (function
		()local res,lights,count =runBake (minCorner,maxCorner,SETTINGS .nx,SETTINGS .ny,SETTINGS .nz,function
			(current,total,elapsed,eta,probeColor,rayData)updateProgress (progressUI,current,total,elapsed,eta,probeColor,rayData)
			end
			)return res,lights,count
		end
		)if ok and type (err)=="table"then
			local success,lights,count =runBake (minCorner,maxCorner,SETTINGS .nx,SETTINGS .ny,SETTINGS .nz,function
			(current,total,elapsed,eta,probeColor,rayData)updateProgress (progressUI,current,total,elapsed,eta,probeColor,rayData)
			end
			)if lights and progressUI and progressUI .populateLights then
				progressUI .populateLights (lights)
			end
		else
			local success,lights,count =runBake (minCorner,maxCorner,SETTINGS .nx,SETTINGS .ny,SETTINGS .nz,function
			(current,total,elapsed,eta,probeColor,rayData)updateProgress (progressUI,current,total,elapsed,eta,probeColor,rayData)
			end
			)if lights and progressUI and progressUI .populateLights then
				progressUI .populateLights (lights)
			end
		end
		hideProgressUI (progressUI)bakeButton .Text ="Bake"bakeButton .BackgroundColor3 =Color3 .fromRGB (65,180,100)bakeButton .Active =true
	end
	)
end
)mainButton .Click:Connect (function
()widget .Enabled =not widget .Enabled
end
)local function
	updateSunFromClock ()if not SETTINGS .autoSun then
		return
	end
	local clock =Lighting .ClockTime or 12 local theta =(clock /24)*2 *math .pi -math .pi /2 local az =math .rad (SETTINGS .sunAzimuth or 0)local x =math .cos (theta)*math .cos (az)local y =math .sin (theta)local z =math .cos (theta)*math .sin (az)SETTINGS .sunDirection =Vector3 .new (x,y,z).Unit local elevation =clamp (y,-1,1)local warmthT =clamp (1 -(elevation +0.1)*0.9,0,1)SETTINGS .sunColor =Color3 .new (lerp (1.0,1.0,1 -warmthT),lerp (1.0,0.90,warmthT),lerp (1.0,0.65,warmthT))
end
Lighting:GetPropertyChangedSignal("ClockTime"):Connect(updateSunFromClock)
azimuthInput.setValue(SETTINGS.sunAzimuth)
math.randomseed(tick() % 1e6)
