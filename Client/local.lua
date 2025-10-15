local ReplicatedStorage =game:GetService ("ReplicatedStorage")local Workspace =game:GetService ("Workspace")local RunService =game:GetService ("RunService")local Players =game:GetService ("Players")local Lighting =game:GetService ("Lighting")local TweenService =game:GetService ("TweenService")local PROBE_FOLDER_NAME ="ProbeBakes"local CLIENT_FOLDER_NAME ="__ProbeBakeClientLights"local PROBE_CAP =math .huge local BRIGHTNESS_MULTIPLIER =1.0 local MIN_BRIGHTNESS =0.001 local MAX_BRIGHTNESS =0.08 local RAY_TRACE_ENABLED =true local GRAPHICS_MODES ={Ultra ={targetFPS =30,raysPerProbe =12,probesPerUpdate =5,rayDistance =25,updateInterval =1 /30},High ={targetFPS =20,raysPerProbe =8,probesPerUpdate =3,rayDistance =20,updateInterval =1 /20},Medium ={targetFPS =15,raysPerProbe =6,probesPerUpdate =2,rayDistance =15,updateInterval =1 /15},Low ={targetFPS =10,raysPerProbe =4,probesPerUpdate =1,rayDistance =12,updateInterval =1 /10}}local CURRENT_MODE ="Low"local ACTIVE_SETTINGS =GRAPHICS_MODES [CURRENT_MODE]local PATH_COLOR_WEIGHT =0.70 local RAY_COLOR_WEIGHT =0.0 local SUN_BIAS_STRENGTH =0.85 local SUN_BIAS_SPREAD =0.25 local INITIAL_CHUNK_SIZE =64 local INITIAL_CHUNK_DELAY =0.10 local REALTIME_RADIUS =10 local REALTIME_RAY_INTERVAL =0.06 local BACKGROUND_UPDATE_INTERVAL =ACTIVE_SETTINGS .updateInterval or 1 /30 local BACKGROUND_PROBES_PER_TICK =ACTIVE_SETTINGS .probesPerUpdate or 3 local REALTIME_ENABLED =true local MAX_RAY_LENGTH =25 local COLOR_SMOOTH_TIME =0.5 local INITIAL_SAMPLING_SMOOTH =0.5 local player =Players .LocalPlayer local allProbes ={}local activeLights ={}local lastRayUpdate =0 local currentProbeIndex =1 local loadingUI =nil local backgroundIndex =1 local realtimeUI =nil local clientFolder =nil local function
	createLoadingUI ()local screenGui =Instance .new ("ScreenGui")screenGui .Name ="ProbeLoadingUI"screenGui .ResetOnSpawn =false local frame =Instance .new ("Frame")frame .Size =UDim2 .new (0,320,0,84)frame .Position =UDim2 .new (0.5,-160,0,20)frame .BackgroundColor3 =Color3 .new (0,0,0)frame .BackgroundTransparency =0.35 frame .BorderSizePixel =0 frame .Parent =screenGui local corner =Instance .new ("UICorner")corner .CornerRadius =UDim .new (0,10)corner .Parent =frame local label =Instance .new ("TextLabel")label .Size =UDim2 .new (1,-20,0,22)label .Position =UDim2 .new (0,10,0,10)label .BackgroundTransparency =1 label .Text ="Preparing..."label .TextColor3 =Color3 .new (1,1,1)label .TextSize =15 label .Font =Enum .Font .GothamBold label .TextXAlignment =Enum .TextXAlignment .Left label .Parent =frame local subLabel =Instance .new ("TextLabel")subLabel .Size =UDim2 .new (1,-20,0,18)subLabel .Position =UDim2 .new (0,10,0,34)subLabel .BackgroundTransparency =1 subLabel .Text =""subLabel .TextColor3 =Color3 .new (0.8,0.8,0.8)subLabel .TextSize =12 subLabel .Font =Enum .Font .Gotham subLabel .TextXAlignment =Enum .TextXAlignment .Left subLabel .Parent =frame local progressBar =Instance .new ("Frame")progressBar .Size =UDim2 .new (1,-20,0,8)progressBar .Position =UDim2 .new (0,10,1,-18)progressBar .BackgroundColor3 =Color3 .new (0.18,0.18,0.18)progressBar .BorderSizePixel =0 progressBar .Parent =frame local progressFill =Instance .new ("Frame")progressFill .Size =UDim2 .new (0,0,1,0)progressFill .BackgroundColor3 =Color3 .new (0.3,0.7,1)progressFill .BorderSizePixel =0 progressFill .Parent =progressBar local progressCorner =Instance .new ("UICorner")progressCorner .CornerRadius =UDim .new (1,0)progressCorner .Parent =progressBar screenGui .Parent =player:WaitForChild ("PlayerGui")return {gui =screenGui,progressFill =progressFill,label =label,subLabel =subLabel}
end
local function
	updateLoadingProgress (ui,progress)if ui and ui .progressFill then
		ui .progressFill .Size =UDim2 .new (math .clamp (progress,0,1),0,1,0)
	end
end
local function
	fadeOutLoadingUI (ui)if not ui then
		return
	end
	local tweenInfo =TweenInfo .new (0.28,Enum .EasingStyle .Quad,Enum .EasingDirection .Out)local frame =ui .gui:FindFirstChildWhichIsA ("Frame")if frame then
		local tween =TweenService:Create (frame,tweenInfo,{BackgroundTransparency =1})tween:Play ()
	end
	for _,child in ipairs (ui .gui:GetDescendants ())do
		if child:IsA ("GuiObject")then
			local childTween =TweenService:Create (child,tweenInfo,{BackgroundTransparency =1})childTween:Play ()
		end
		if child:IsA ("TextLabel")or child:IsA ("TextButton")then
			local textTween =TweenService:Create (child,tweenInfo,{TextTransparency =1})textTween:Play ()
		end
	end
	delay (0.32,function
	()if ui .gui and ui .gui .Parent then
			ui .gui:Destroy ()
		end
	end
	)
end
local function
	createRealtimeUI ()if realtimeUI and realtimeUI .gui and realtimeUI .gui .Parent then
		return realtimeUI
	end
	local screenGui =Instance .new ("ScreenGui")screenGui .Name ="ProbeRealtimeUI"screenGui .ResetOnSpawn =false local frame =Instance .new ("Frame")frame .Size =UDim2 .new (0,220,0,104)frame .Position =UDim2 .new (1,-230,0,18)frame .BackgroundColor3 =Color3 .new (0,0,0)frame .BackgroundTransparency =0.35 frame .BorderSizePixel =0 frame .Parent =screenGui local corner =Instance .new ("UICorner")corner .CornerRadius =UDim .new (0,10)corner .Parent =frame local title =Instance .new ("TextLabel")title .Size =UDim2 .new (1,-20,0,20)title .Position =UDim2 .new (0,10,0,8)title .BackgroundTransparency =1 title .Text ="Realtime Raytracer"title .TextColor3 =Color3 .new (1,1,1)title .TextSize =14 title .Font =Enum .Font .GothamBold title .TextXAlignment =Enum .TextXAlignment .Left title .Parent =frame local status =Instance .new ("TextLabel")status .Size =UDim2 .new (1,-20,0,18)status .Position =UDim2 .new (0,10,0,28)status .BackgroundTransparency =1 status .Text =("Status: %s"):format (REALTIME_ENABLED and "On"or "Off")status .TextColor3 =Color3 .new (0.85,0.85,0.85)status .TextSize =12 status .Font =Enum .Font .Gotham status .TextXAlignment =Enum .TextXAlignment .Left status .Parent =frame local toggleBtn =Instance .new ("TextButton")toggleBtn .Size =UDim2 .new (0,84,0,28)toggleBtn .Position =UDim2 .new (0,10,0,50)toggleBtn .BackgroundColor3 =Color3 .new (0.16,0.16,0.16)toggleBtn .BorderSizePixel =0 toggleBtn .Text =REALTIME_ENABLED and "Realtime: ON"or "Realtime: OFF"toggleBtn .TextColor3 =Color3 .new (1,1,1)toggleBtn .Font =Enum .Font .GothamBold toggleBtn .TextSize =13 toggleBtn .Parent =frame local radiusLabel =Instance .new ("TextLabel")radiusLabel .Size =UDim2 .new (0,100,0,18)radiusLabel .Position =UDim2 .new (0,110,0,52)radiusLabel .BackgroundTransparency =1 radiusLabel .Text =("Radius: %d"):format (REALTIME_RADIUS)radiusLabel .TextColor3 =Color3 .new (0.8,0.8,0.8)radiusLabel .Font =Enum .Font .Gotham radiusLabel .TextSize =12 radiusLabel .TextXAlignment =Enum .TextXAlignment .Left radiusLabel .Parent =frame local speedLabel =Instance .new ("TextLabel")speedLabel .Size =UDim2 .new (1,-20,0,18)speedLabel .Position =UDim2 .new (0,10,0,76)speedLabel .BackgroundTransparency =1 speedLabel .Text =("Interval: %.2fs"):format (REALTIME_RAY_INTERVAL)speedLabel .TextColor3 =Color3 .new (0.8,0.8,0.8)speedLabel .Font =Enum .Font .Gotham speedLabel .TextSize =12 speedLabel .TextXAlignment =Enum .TextXAlignment .Left speedLabel .Parent =frame local function
		updateUI ()if not (status and toggleBtn and radiusLabel and speedLabel)then
			return
		end
		status .Text =("Status: %s"):format (REALTIME_ENABLED and "On"or "Off")toggleBtn .Text =REALTIME_ENABLED and "Realtime: ON"or "Realtime: OFF"radiusLabel .Text =("Radius: %d"):format (REALTIME_RADIUS)speedLabel .Text =("Interval: %.2fs"):format (REALTIME_RAY_INTERVAL)
	end
	toggleBtn .MouseButton1Click:Connect (function
	()REALTIME_ENABLED =not REALTIME_ENABLED updateUI ()local tweenInfo =TweenInfo .new (0.18,Enum .EasingStyle .Quad,Enum .EasingDirection .Out)local colorGoal =REALTIME_ENABLED and {BackgroundTransparency =0.35}or {BackgroundTransparency =0.85}local tween =TweenService:Create (frame,tweenInfo,colorGoal)tween:Play ()
	end
	)local incBtn =Instance .new ("TextButton")incBtn .Size =UDim2 .new (0,20,0,18)incBtn .Position =UDim2 .new (0,204,0,52)incBtn .BackgroundTransparency =0.2 incBtn .Text ="+"incBtn .Font =Enum .Font .GothamBold incBtn .TextSize =14 incBtn .Parent =frame incBtn .MouseButton1Click:Connect (function
	()REALTIME_RADIUS =math .min (64,REALTIME_RADIUS +2)updateUI ()
	end
	)local decBtn =Instance .new ("TextButton")decBtn .Size =UDim2 .new (0,20,0,18)decBtn .Position =UDim2 .new (0,180,0,52)decBtn .BackgroundTransparency =0.2 decBtn .Text ="-"decBtn .Font =Enum .Font .GothamBold decBtn .TextSize =14 decBtn .Parent =frame decBtn .MouseButton1Click:Connect (function
	()REALTIME_RADIUS =math .max (2,REALTIME_RADIUS -2)updateUI ()
	end
	)local incSpeed =Instance .new ("TextButton")incSpeed .Size =UDim2 .new (0,20,0,18)incSpeed .Position =UDim2 .new (0,204,0,76)incSpeed .BackgroundTransparency =0.2 incSpeed .Text ="<"incSpeed .Font =Enum .Font .GothamBold incSpeed .TextSize =12 incSpeed .Parent =frame incSpeed .MouseButton1Click:Connect (function
	()REALTIME_RAY_INTERVAL =math .max (0.02,REALTIME_RAY_INTERVAL -0.01)updateUI ()
	end
	)local decSpeed =Instance .new ("TextButton")decSpeed .Size =UDim2 .new (0,20,0,18)decSpeed .Position =UDim2 .new (0,180,0,76)decSpeed .BackgroundTransparency =0.2 decSpeed .Text =">"decSpeed .Font =Enum .Font .GothamBold decSpeed .TextSize =12 decSpeed .Parent =frame decSpeed .MouseButton1Click:Connect (function
	()REALTIME_RAY_INTERVAL =math .min (0.5,REALTIME_RAY_INTERVAL +0.02)updateUI ()
	end
	)screenGui .Parent =player:WaitForChild ("PlayerGui")realtimeUI ={gui =screenGui,frame =frame,update =updateUI}updateUI ()return realtimeUI
end
local function
	fadeOutRealtimeUI (ui)if not ui or not ui .frame then
		return
	end
	local tweenInfo =TweenInfo .new (0.28,Enum .EasingStyle .Quad,Enum .EasingDirection .Out)local tween =TweenService:Create (ui .frame,tweenInfo,{BackgroundTransparency =1})tween:Play ()delay (0.32,function
	()if ui .gui and ui .gui .Parent then
			ui .gui:Destroy ()
		end
		realtimeUI =nil
	end
	)
end
local function
	findBakeModules ()local folder =ReplicatedStorage:FindFirstChild (PROBE_FOLDER_NAME)if not folder then
		return nil,"No "..PROBE_FOLDER_NAME .." folder in ReplicatedStorage"
	end
	local modules ={}for _,child in ipairs (folder:GetChildren ())do
		if child:IsA ("ModuleScript")then
			if child .Name:match ("_part%d+$")then
			elseif
				child .Name:match ("^bake_")then
				table .insert (modules,child)
			end
		end
	end
	if #modules ==0 then
		return nil,"No ModuleScript found in "..PROBE_FOLDER_NAME .." (after filtering _part chunks)"
	end
	return modules
end
local function
	decodeQuantizedCoord (q,minv,maxv)local t =q /65535 return minv +t *(maxv -minv)
end
local function
	clearClientLights ()local existing =Workspace:FindFirstChild (CLIENT_FOLDER_NAME)if existing and existing .Parent then
		existing:Destroy ()
	end
	allProbes ={}activeLights ={}clientFolder =nil
end
local function
	getSunDirection ()local dirLight =Lighting:FindFirstChildOfClass ("DirectionalLight")if dirLight then
		if typeof (dirLight .Direction)=="Vector3"and dirLight .Direction .Magnitude >0 then
			return dirLight .Direction .Unit
		end
		if typeof (dirLight .Rotation)=="CFrame"then
			local v =dirLight .Rotation .LookVector if v .Magnitude >0 then
				return v .Unit
			end
		end
	end
	local clock =Lighting .ClockTime or 12 local t =(clock /24)*2 *math .pi local elevationAngle =math .sin (t)*(math .pi /2)local azimuth =t local x =math .cos (elevationAngle)*math .cos (azimuth)local y =math .sin (elevationAngle)local z =math .cos (elevationAngle)*math .sin (azimuth)local v =Vector3 .new (x,y,z)if v .Magnitude ==0 then
		return Vector3 .new (0,1,0)
	end
	return v .Unit
end
local function
	sampleEnvironmentAt (position)if not RAY_TRACE_ENABLED then
		return Color3 .new (1,1,1),Vector3 .new (0,1,0),(ACTIVE_SETTINGS and ACTIVE_SETTINGS .rayDistance)or MAX_RAY_LENGTH,1
	end
	local raycastParams =RaycastParams .new ()raycastParams .FilterType =Enum .RaycastFilterType .Exclude local character =player .Character local filterInstances ={}if character then
		table .insert (filterInstances,character)
	end
	if not clientFolder then
		clientFolder =Workspace:FindFirstChild (CLIENT_FOLDER_NAME)
	end
	if clientFolder then
		table .insert (filterInstances,clientFolder)
	end
	raycastParams .FilterDescendantsInstances =filterInstances raycastParams .IgnoreWater =true local baseDirections ={Vector3 .new (1,0,0),Vector3 .new (-1,0,0),Vector3 .new (0,1,0),Vector3 .new (0,-1,0),Vector3 .new (0,0,1),Vector3 .new (0,0,-1),Vector3 .new (1,1,0).Unit,Vector3 .new (-1,1,0).Unit,Vector3 .new (1,-1,0).Unit,Vector3 .new (-1,-1,0).Unit,Vector3 .new (1,0,1).Unit,Vector3 .new (-1,0,1).Unit,Vector3 .new (1,0,-1).Unit,Vector3 .new (-1,0,-1).Unit,}local ok,sunDir =pcall (getSunDirection)if not ok or not sunDir or sunDir .Magnitude ==0 then
		sunDir =Vector3 .new (0,1,0)
	end
	local awayFromSun =(-sunDir).Unit local sunBias =(type (SUN_BIAS_STRENGTH)=="number")and SUN_BIAS_STRENGTH or 0.9 local biasSpread =(type (SUN_BIAS_SPREAD)=="number")and SUN_BIAS_SPREAD or 0.25 local numBase =#baseDirections local numRays =math .max (1,math .min ((ACTIVE_SETTINGS and ACTIVE_SETTINGS .raysPerProbe)or 6,numBase))local directions ={}for i =1,numRays do
		local b =baseDirections [i]or baseDirections [1]local blended =(b *(1 -sunBias)+awayFromSun *sunBias)local spread =Vector3 .new ((math .random ()-0.5)*biasSpread,(math .random ()-0.5)*biasSpread,(math .random ()-0.5)*biasSpread)local final =blended +spread if final .Magnitude ==0 then
			final =Vector3 .new (0,1,0)
		end
		table .insert (directions,final .Unit)
	end
	local colorSum =Vector3 .new (0,0,0)local normalSum =Vector3 .new (0,0,0)local distSum =0 local hits =0 local actualHits =0 local maxDist =math .min (MAX_RAY_LENGTH,(ACTIVE_SETTINGS and ACTIVE_SETTINGS .rayDistance)or MAX_RAY_LENGTH)for i =1,#directions do
		local dir =directions [i]or directions [1]local res =Workspace:Raycast (position,dir *maxDist,raycastParams)if res and res .Instance then
			local hitPart =res .Instance if hitPart .Name =="__ProbeLight"or (hitPart .Parent and hitPart .Parent .Name:find ("__ProbeModule_"))then
				local ambient =Lighting .Ambient or Color3 .new (0.5,0.5,0.5)colorSum =colorSum +Vector3 .new (ambient .R,ambient .G,ambient .B)distSum =distSum +maxDist hits =hits +1
			else
				local partColor =hitPart .Color local mat =res .Material local materialBrightness =1.0 if mat ==Enum .Material .Neon then materialBrightness =1.5 elseif mat ==Enum .Material .Glass then materialBrightness =1.2 elseif mat ==Enum .Material .Metal then materialBrightness =0.8 elseif mat ==Enum .Material .Concrete or mat ==Enum .Material .Brick then materialBrightness =0.6 elseif mat ==Enum .Material .Wood then 
					materialBrightness =0.7
				end
				colorSum =colorSum +Vector3 .new (partColor .R,partColor .G,partColor .B)*materialBrightness if res .Normal then
					normalSum =normalSum +res .Normal
				end
				distSum =distSum +(res .Distance or maxDist)hits =hits +1 actualHits =actualHits +1
			end
		else
			local ambient =Lighting .Ambient or Color3 .new (0.5,0.5,0.5)colorSum =colorSum +Vector3 .new (ambient .R,ambient .G,ambient .B)distSum =distSum +maxDist hits =hits +1
		end
	end
	if hits >0 then
		local avgColor =colorSum /hits local avgNormal =(normalSum .Magnitude >0 and normalSum .Unit)or Vector3 .new (0,1,0)local avgDist =distSum /hits return Color3 .new (math .clamp (avgColor .X,0,1),math .clamp (avgColor .Y,0,1),math .clamp (avgColor .Z,0,1)),avgNormal,avgDist,actualHits
	end
	return Color3 .new (1,1,1),Vector3 .new (0,1,0),maxDist,actualHits
end
local function
	isProbeRealtime (probePos)local char =player .Character if not char then
		return false
	end
	local hrp =char:FindFirstChild ("HumanoidRootPart")if not hrp then
		return false
	end
	local d =(hrp .Position -probePos).Magnitude return d <=REALTIME_RADIUS
end
local faceVectors ={Top =Vector3 .new (0,1,0),Bottom =Vector3 .new (0,-1,0),Front =Vector3 .new (0,0,-1),Back =Vector3 .new (0,0,1),Right =Vector3 .new (1,0,0),Left =Vector3 .new (-1,0,0),}local function
	tweenSurfaceLightProperties (sl,newColor,newBrightness,newRange,smoothTime)if not sl or not sl .Parent then
		return
	end
	local info =TweenInfo .new (math .max (0.01,smoothTime or COLOR_SMOOTH_TIME),Enum .EasingStyle .Quad,Enum .EasingDirection .Out)local ok,err =pcall (function
	()local props ={}if newColor then
			props .Color =newColor
		end
		if newBrightness then
			props .Brightness =newBrightness
		end
		if newRange then
			props .Range =newRange
		end
		local tween =TweenService:Create (sl,info,props)tween:Play ()
	end
	)if not ok then
		if newColor then
			sl .Color =newColor
		end
		if newBrightness then
			sl .Brightness =newBrightness
		end
		if newRange then
			sl .Range =newRange
		end
	end
end
local function
	applySampleToProbe (probeData,sampledColor,sampledNormal,sampledDistance,smoothTimeOverride)if not probeData or not probeData .part or not probeData .surfaceLights then
		return
	end
	local blended =probeData .originalColor:Lerp (sampledColor,RAY_COLOR_WEIGHT)local originalLuminance =(probeData .originalColor .R *0.299 +probeData .originalColor .G *0.587 +probeData .originalColor .B *0.114)local blendedLuminance =(blended .R *0.299 +blended .G *0.587 +blended .B *0.114)local brightnessFactor =1.0 if blendedLuminance >0.001 then
		brightnessFactor =originalLuminance /blendedLuminance
	end
	blended =Color3 .new (math .clamp (blended .R *brightnessFactor,0,1),math .clamp (blended .G *brightnessFactor,0,1),math .clamp (blended .B *brightnessFactor,0,1))local desiredRange =math .clamp ((sampledDistance or MAX_RAY_LENGTH)*1.2,6,64)local lastCol =probeData ._lastSampledColor local colorDelta =0 if lastCol and sampledColor then
		local dv =Vector3 .new (sampledColor .R -lastCol .R,sampledColor .G -lastCol .G,sampledColor .B -lastCol .B)colorDelta =dv .Magnitude
	end
	local baseSmooth =smoothTimeOverride or COLOR_SMOOTH_TIME local scaledSmooth =math .clamp (baseSmooth *(1 +colorDelta *3.0),0.05,0.8)for faceName,sData in pairs (probeData .surfaceLights)do
		local sl =sData .light if sl then
			local localFaceVec =faceVectors [faceName]or Vector3 .new (0,1,0)local faceWorldNormal =probeData .part .CFrame:VectorToWorldSpace (localFaceVec).Unit local weight =math .max (0,faceWorldNormal:Dot (sampledNormal))local brightness =math .clamp ((probeData .strength or 1)*BRIGHTNESS_MULTIPLIER *(0.5 +weight *0.5),MIN_BRIGHTNESS,MAX_BRIGHTNESS)tweenSurfaceLightProperties (sl,blended,brightness,desiredRange,scaledSmooth)if sl:IsA ("SurfaceLight")then
				sl .Angle =180
			end
		end
	end
	probeData ._lastSampled =tick ()probeData ._lastSampledColor =sampledColor probeData ._lastSampledNormal =sampledNormal probeData ._lastSampledDistance =sampledDistance
end
local function
	sampleAndApplyProbe (probeData,smoothTimeOverride)local ok,sampledColor,sampledNormal,sampledDistance =pcall (function
	()return sampleEnvironmentAt (probeData .position)
	end
	)if ok and sampledColor then
		applySampleToProbe (probeData,sampledColor,sampledNormal,sampledDistance,smoothTimeOverride)return true
	end
	return false
end
local function
	restoreProbesToOriginal ()for _,probeData in ipairs (allProbes)do
		if probeData .surfaceLights then
			for _,s in pairs (probeData .surfaceLights)do
				local sl =s .light if sl and sl .Parent then
					local origBrightness =math .clamp ((probeData .strength or 1)*BRIGHTNESS_MULTIPLIER *0.5,MIN_BRIGHTNESS,MAX_BRIGHTNESS)tweenSurfaceLightProperties (sl,probeData .originalColor,origBrightness,probeData .range or 12,COLOR_SMOOTH_TIME)
				end
			end
		end
	end
end
local function
	updateRayTracing ()if not RAY_TRACE_ENABLED or #allProbes ==0 then
		return
	end
	local currentTime =tick ()if currentTime -lastRayUpdate <BACKGROUND_UPDATE_INTERVAL then
	else
		local attempts =0 local sampledThisTick =0 while sampledThisTick <BACKGROUND_PROBES_PER_TICK and attempts <#allProbes do
			if backgroundIndex >#allProbes then
				backgroundIndex =1
			end
			local p =allProbes [backgroundIndex]backgroundIndex =backgroundIndex +1 attempts =attempts +1 if p and p .part and p .part .Parent then
				if not isProbeRealtime (p .position)then
					task .spawn (function
					()pcall (function
						()sampleAndApplyProbe (p)
						end
						)
					end
					)sampledThisTick =sampledThisTick +1
				end
			end
		end
		lastRayUpdate =currentTime
	end
	if REALTIME_ENABLED then
		local char =player .Character local hrp =char and char:FindFirstChild ("HumanoidRootPart")if hrp then
			local hrpPos =hrp .Position for _,p in ipairs (allProbes)do
				if p and p .part and p .part .Parent then
					local dist =(p .position -hrpPos).Magnitude if dist <=REALTIME_RADIUS then
						local last =p ._lastSampled or 0 if tick ()-last >=REALTIME_RAY_INTERVAL then
							task .spawn (function
							()pcall (function
								()sampleAndApplyProbe (p,math .max (0.06,COLOR_SMOOTH_TIME *0.5))
								end
								)
							end
							)
						end
					end
				end
			end
		end
	end
end
local function
	createSurfaceLightsForPart (part,baseColor,baseStrength,baseRange)local lights ={}local faceOrder ={{name ="Top",face =Enum .NormalId .Top,localVec =Vector3 .new (0,1,0)},{name ="Bottom",face =Enum .NormalId .Bottom,localVec =Vector3 .new (0,-1,0)},{name ="Front",face =Enum .NormalId .Front,localVec =Vector3 .new (0,0,-1)},{name ="Back",face =Enum .NormalId .Back,localVec =Vector3 .new (0,0,1)},{name ="Right",face =Enum .NormalId .Right,localVec =Vector3 .new (1,0,0)},{name ="Left",face =Enum .NormalId .Left,localVec =Vector3 .new (-1,0,0)},}for _,f in ipairs (faceOrder)do
		local sl =Instance .new ("SurfaceLight")sl .Name ="__ProbeSurfaceLight_"..f .name sl .Face =f .face sl .Range =baseRange or 12 sl .Brightness =math .clamp ((baseStrength or 1)*BRIGHTNESS_MULTIPLIER *0.5,MIN_BRIGHTNESS,MAX_BRIGHTNESS)sl .Angle =90 sl .Color =baseColor or Color3 .new (1,1,1)sl .Enabled =true sl .Parent =part lights [f .name]={light =sl,localVec =f .localVec}
	end
	return lights
end
local function
	setupClientLightsForModule (mod,perModuleCap,globalRemaining,loadingUI,initialCreateStepCallback)assert (mod,"module required")local ok,M =pcall (require,mod)if not ok then
		warn ("Failed to require probe module:",M)return false,"require failed: "..tostring (M),0
	end
	if type (M)~="table"then
		return false,("Module '%s' did not return a table (skipping)."):format (tostring (mod .Name)),0
	end
	if not (M .minBound and M .maxBound and M .nx and M .ny and M .nz and M .getProbe and M .count)then
		return false,"Module missing expected fields (minBound/maxBound/nx/ny/nz/getProbe/count)",0
	end
	local count =tonumber (M .count)or 0 if count <=0 then
		return false,"No probes in module",0
	end
	local root =Workspace:FindFirstChild (CLIENT_FOLDER_NAME)if not root then
		root =Instance .new ("Folder")root .Name =CLIENT_FOLDER_NAME root .Parent =Workspace clientFolder =root
	end
	local modFolderName ="__ProbeModule_"..tostring (mod .Name)local folder =Instance .new ("Folder")folder .Name =modFolderName folder .Parent =root local step =1 if perModuleCap and perModuleCap >0 and perModuleCap <math .huge and count >perModuleCap then
		step =math .ceil (count /perModuleCap)
	end
	local created =0 for i =1,count,step do
		if globalRemaining and globalRemaining <=0 then
			break
		end
		local p local ok2,res =pcall (function
		()return M .getProbe (i)
		end
		)if ok2 then
			p =res
		else
			p =nil
		end
		if p and p .qx and p .qy and p .qz then
			local x =decodeQuantizedCoord (p .qx,M .minBound .X,M .maxBound .X)local y =decodeQuantizedCoord (p .qy,M .minBound .Y,M .maxBound .Y)local z =decodeQuantizedCoord (p .qz,M .minBound .Z,M .maxBound .Z)local pos =Vector3 .new (x,y,z)local part =Instance .new ("Part")part .Name ="__ProbeLight"part .Size =Vector3 .new (0.2,0.2,0.2)part .Anchored =true part .CanCollide =false part .Transparency =1 part .CFrame =CFrame .new (pos)part .Parent =folder local originalColor if p .color and typeof (p .color)=="Color3"then
				originalColor =p .color
			else
				originalColor =(Lighting .OutdoorAmbient or Lighting .Ambient)or Color3 .new (0.2,0.2,0.25)
			end
			local strength =(p .strength and tonumber (p .strength))or 1 local surfaceLights =createSurfaceLightsForPart (part,originalColor,strength,12)local probeData ={part =part,originalColor =originalColor,range =12,position =pos,strength =strength,surfaceLights =surfaceLights,_lastSampled =0,_lastSampledColor =nil,}table .insert (allProbes,probeData)table .insert (activeLights,{part =part,lights =surfaceLights})created =created +1 if globalRemaining then
				globalRemaining =globalRemaining -1
			end
			if loadingUI and created %8 ==0 then
				updateLoadingProgress (loadingUI,created /count)if initialCreateStepCallback then
					pcall (initialCreateStepCallback,created,count)
				end
			end
		end
	end
	return true,("Module '%s': Created %d lights (from %d probes, step=%d)"):format (mod .Name,created,count,step),created
end
local function
	initialThrottledFullTrace (onProgress,smoothTimeForInitial)if #allProbes ==0 then
		return
	end
	local total =#allProbes local processed =0 local idx =1 while idx <=total do
		local chunkEnd =math .min (total,idx +INITIAL_CHUNK_SIZE -1)for i =idx,chunkEnd do
			local p =allProbes [i]if p and p .part and p .part .Parent then
				pcall (function
				()local ok =sampleAndApplyProbe (p,smoothTimeForInitial or INITIAL_SAMPLING_SMOOTH)
				end
				)
			end
			processed =processed +1
		end
		if onProgress then
			pcall (onProgress,processed /total)
		end
		task .wait (INITIAL_CHUNK_DELAY)idx =chunkEnd +1
	end
end
local function
	run ()loadingUI =createLoadingUI ()updateLoadingProgress (loadingUI,0)loadingUI .label .Text ="Scanning probe modules..."loadingUI .subLabel .Text ="Searching for probe data in ReplicatedStorage"local mods,err =findBakeModules ()if not mods then
		warn ("Probe bake modules not found:",err)if loadingUI then
			loadingUI .label .Text ="No probes found"loadingUI .subLabel .Text =err task .wait (1.0)fadeOutLoadingUI (loadingUI)
		end
		return
	end
	local perModuleCap if PROBE_CAP ==math .huge then
		perModuleCap =math .huge
	else
		perModuleCap =math .max (1,math .floor (PROBE_CAP /#mods))
	end
	local root =Workspace:FindFirstChild (CLIENT_FOLDER_NAME)if root then
		root:Destroy ()
	end
	allProbes ={}activeLights ={}clientFolder =nil local totalCreated =0 local remainingGlobal =PROBE_CAP loadingUI .label .Text ="Creating probe parts..."loadingUI .subLabel .Text ="Instantiating probe holders (throttled to avoid spikes)"for idx,mod in ipairs (mods)do
		if remainingGlobal and remainingGlobal <=0 then
			warn ("Global probe cap reached ("..tostring (PROBE_CAP).."). Stopping further module instantiation.")break
		end
		if loadingUI then
			loadingUI .subLabel .Text =string .format ("Module %d/%d: %s",idx,#mods,mod .Name)
		end
		local localCap =perModuleCap if remainingGlobal and remainingGlobal <localCap then
			localCap =remainingGlobal
		end
		local ok,msg,created =setupClientLightsForModule (mod,localCap,remainingGlobal,loadingUI,function
		(createdSoFar,moduleCount)if loadingUI and loadingUI .subLabel then
				loadingUI .subLabel .Text =("Creating parts... %d/%d"):format (#allProbes,moduleCount)
			end
		end
		)if ok then
			print (msg)totalCreated =totalCreated +(created or 0)if remainingGlobal then
				remainingGlobal =PROBE_CAP -totalCreated
			end
		else
			warn ("Failed to setup lights for module '"..tostring (mod .Name).."':",msg)
		end
		updateLoadingProgress (loadingUI,idx /#mods)task .wait (0.04)
	end
	if loadingUI then
		loadingUI .label .Text ="Sampling environment..."loadingUI .subLabel .Text ="Performing initial shot to collect colors"updateLoadingProgress (loadingUI,0)
	end
	task .spawn (function
	()initialThrottledFullTrace (function
		(progress)if loadingUI then
				updateLoadingProgress (loadingUI,progress)loadingUI .subLabel .Text =string .format ("Sampling probes: %d/%d",math .floor (progress *#allProbes),#allProbes)
			end
		end ,INITIAL_SAMPLING_SMOOTH)task .wait (0.25)if loadingUI then
			loadingUI .label .Text ="Preparing realtime tracer..."loadingUI .subLabel .Text ="Finalizing colors and warming up raytracer"updateLoadingProgress (loadingUI,0)
		end
		local warmTotal =0 for _,p in ipairs (allProbes)do
			if isProbeRealtime (p .position)then
				warmTotal =warmTotal +1
			end
		end
		local warmed =0 if warmTotal >0 then
			for _,p in ipairs (allProbes)do
				if isProbeRealtime (p .position)then
					pcall (function
					()sampleAndApplyProbe (p,COLOR_SMOOTH_TIME *1.0)
					end
					)warmed =warmed +1 if loadingUI then
						updateLoadingProgress (loadingUI,warmed /warmTotal)loadingUI .subLabel .Text =("Warming realtime probes: %d/%d"):format (warmed,warmTotal)
					end
					task .wait (0.02)
				end
			end
		else
			local N =math .min (40,#allProbes)for i =1,N do
				local p =allProbes [i]if p then
					pcall (function
					()sampleAndApplyProbe (p,COLOR_SMOOTH_TIME)
					end
					)
				end
				if loadingUI then
					updateLoadingProgress (loadingUI,i /N)loadingUI .subLabel .Text =("Warming probes: %d/%d"):format (i,N)
				end
				task .wait (0.02)
			end
		end
		if loadingUI then
			loadingUI .label .Text ="Complete!"loadingUI .subLabel .Text ="Ray tracing starting..."updateLoadingProgress (loadingUI,1)task .wait (0.5)fadeOutLoadingUI (loadingUI)loadingUI =nil
		end
		print (("Finished creating lights for %d modules. Total lights created: %d (global cap=%s)"):format (#mods,totalCreated,tostring (PROBE_CAP)))print (("Graphics Mode: %s (%d FPS target)"):format (CURRENT_MODE,ACTIVE_SETTINGS .targetFPS))createRealtimeUI ()if RAY_TRACE_ENABLED and totalCreated >0 then
			pcall (function
			()RunService:UnbindFromRenderStep ("ProbeRayTracing")
			end
			)RunService:BindToRenderStep ("ProbeRayTracing",Enum .RenderPriority .Last .Value,updateRayTracing)print ("Ray tracing enabled - sampling environment colors (60% path / 40% ray blend)")
		end
	end
	)
end
local function
	cleanup ()pcall (function
	()RunService:UnbindFromRenderStep ("ProbeRayTracing")
	end
	)clearClientLights ()if loadingUI then
		if loadingUI .gui and loadingUI .gui .Parent then
			loadingUI .gui:Destroy ()
		end
		loadingUI =nil
	end
	if realtimeUI then
		if realtimeUI .gui and realtimeUI .gui .Parent then
			realtimeUI .gui:Destroy ()
		end
		realtimeUI =nil
	end
end
local clientApi ={setupAll =run,clear =cleanup,findModules =findBakeModules,setupByName =function
(name)local mods,err =findBakeModules ()if not mods then
		return false,err
	end
	for _,mod in ipairs (mods)do
		if mod .Name ==name then
			cleanup ()local ok,msg =setupClientLightsForModule (mod)return ok,msg
		end
	end
	return false,"Module named '"..tostring (name).."' not found"
end
,setBrightnessMultiplier =function
(v)local n =tonumber (v)if not n then
		return false,"invalid number"
	end
	BRIGHTNESS_MULTIPLIER =n for _,lightInfo in ipairs (activeLights)do
		if lightInfo .lights then
			for _,s in pairs (lightInfo .lights)do
				local sl =s .light if sl and sl .Parent then
					sl .Brightness =math .clamp ((sl .Brightness or MIN_BRIGHTNESS)*n,MIN_BRIGHTNESS,MAX_BRIGHTNESS)
				end
			end
		end
	end
	return true,("BRIGHTNESS_MULTIPLIER set to %s"):format (tostring (n))
end
,getBrightnessMultiplier =function
()return BRIGHTNESS_MULTIPLIER
end
,setRayTracingEnabled =function
(enabled)RAY_TRACE_ENABLED =enabled if enabled and #allProbes >0 then
		pcall (function
		()RunService:BindToRenderStep ("ProbeRayTracing",Enum .RenderPriority .Last .Value,updateRayTracing)
		end
		)createRealtimeUI ()
	else
		pcall (function
		()RunService:UnbindFromRenderStep ("ProbeRayTracing")
		end
		)restoreProbesToOriginal ()if realtimeUI then
			fadeOutRealtimeUI (realtimeUI)
		end
	end
	return true,("Ray tracing %s"):format (enabled and "enabled"or "disabled")
end
,setGraphicsMode =function
(mode)local modeUpper =string .upper (string .sub (mode,1,1))..string .lower (string .sub (mode,2))if not GRAPHICS_MODES [modeUpper]then
		return false,("Invalid mode. Available: %s"):format (table .concat ({"Ultra","High","Medium","Low"},", "))
	end
	CURRENT_MODE =modeUpper ACTIVE_SETTINGS =GRAPHICS_MODES [CURRENT_MODE]BACKGROUND_UPDATE_INTERVAL =ACTIVE_SETTINGS .updateInterval or BACKGROUND_UPDATE_INTERVAL BACKGROUND_PROBES_PER_TICK =ACTIVE_SETTINGS .probesPerUpdate or BACKGROUND_PROBES_PER_TICK return true,("Graphics mode set to %s (%d FPS target, %d rays/probe, %d probes/update)"):format (CURRENT_MODE,ACTIVE_SETTINGS .targetFPS,ACTIVE_SETTINGS .raysPerProbe,ACTIVE_SETTINGS .probesPerUpdate)
end
,getGraphicsMode =function
()return CURRENT_MODE,ACTIVE_SETTINGS
end
,setColorBlendFactor =function
(v)local n =tonumber (v)if not n or n <0 or n >1 then
		return false,"invalid number (must be 0-1)"
	end
	RAY_COLOR_WEIGHT =n PATH_COLOR_WEIGHT =1 -n return true,("Color blend: %d%% pathtraced / %d%% raytraced"):format (math .floor (PATH_COLOR_WEIGHT *100),math .floor (RAY_COLOR_WEIGHT *100))
end
,getColorBlend =function
()return PATH_COLOR_WEIGHT,RAY_COLOR_WEIGHT
end
,setMaxRayLength =function
(v)local n =tonumber (v)if not n or n <=0 then
		return false,"invalid number (must be > 0)"
	end
	MAX_RAY_LENGTH =math .min (100,math .max (1,n))return true,("Maximum ray length set to %d"):format (MAX_RAY_LENGTH)
end
,getMaxRayLength =function
()return MAX_RAY_LENGTH
end
}pcall (function
()_G .clientProbeLighting =clientApi
end
)run ()Players .PlayerRemoving:Connect (function
(leavingPlayer)if leavingPlayer ==player then
		cleanup ()
	end
end
)
