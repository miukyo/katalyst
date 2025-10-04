local UserInputService = game:GetService("UserInputService")

local Framework = {}

-- =========================================================
-- Default Props
-- =========================================================
local defaultProps = {
	-- ScreenGui = {
	-- 	ResetOnSpawn = false,
	-- 	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	-- },

	-- BillboardGui = {
	-- 	ResetOnSpawn = false,
	-- 	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	-- 	Active = true,
	-- },

	-- SurfaceGui = {
	-- 	ResetOnSpawn = false,
	-- 	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	-- 	SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
	-- 	PixelsPerStud = 50,
	-- },

	-- Frame = {
	-- 	BackgroundColor3 = Color3.new(1, 1, 1),
	-- 	BorderColor3 = Color3.new(0, 0, 0),
	-- 	BorderSizePixel = 0,
	-- },

	-- ScrollingFrame = {
	-- 	BackgroundColor3 = Color3.new(1, 1, 1),
	-- 	BorderColor3 = Color3.new(0, 0, 0),
	-- 	BorderSizePixel = 0,
	-- 	ScrollBarImageColor3 = Color3.new(0, 0, 0),
	-- },

	-- TextLabel = {
	-- 	BackgroundColor3 = Color3.new(1, 1, 1),
	-- 	BorderColor3 = Color3.new(0, 0, 0),
	-- 	BorderSizePixel = 0,
	-- 	Font = Enum.Font.SourceSans,
	-- 	Text = "",
	-- 	TextColor3 = Color3.new(0, 0, 0),
	-- 	TextSize = 14,
	-- },

	-- TextButton = {
	-- 	BackgroundColor3 = Color3.new(1, 1, 1),
	-- 	BorderColor3 = Color3.new(0, 0, 0),
	-- 	BorderSizePixel = 0,
	-- 	AutoButtonColor = false,
	-- 	Font = Enum.Font.SourceSans,
	-- 	Text = "",
	-- 	TextColor3 = Color3.new(0, 0, 0),
	-- 	TextSize = 14,
	-- },

	-- TextBox = {
	-- 	BackgroundColor3 = Color3.new(1, 1, 1),
	-- 	BorderColor3 = Color3.new(0, 0, 0),
	-- 	BorderSizePixel = 0,
	-- 	ClearTextOnFocus = false,
	-- 	Font = Enum.Font.SourceSans,
	-- 	Text = "",
	-- 	TextColor3 = Color3.new(0, 0, 0),
	-- 	TextSize = 14,
	-- },

	-- ImageLabel = {
	-- 	BackgroundColor3 = Color3.new(1, 1, 1),
	-- 	BorderColor3 = Color3.new(0, 0, 0),
	-- 	BorderSizePixel = 0,
	-- },

	-- ImageButton = {
	-- 	BackgroundColor3 = Color3.new(1, 1, 1),
	-- 	BorderColor3 = Color3.new(0, 0, 0),
	-- 	BorderSizePixel = 0,
	-- 	AutoButtonColor = false,
	-- },

	-- ViewportFrame = {
	-- 	BackgroundColor3 = Color3.new(1, 1, 1),
	-- 	BorderColor3 = Color3.new(0, 0, 0),
	-- 	BorderSizePixel = 0,
	-- },

	-- VideoFrame = {
	-- 	BackgroundColor3 = Color3.new(1, 1, 1),
	-- 	BorderColor3 = Color3.new(0, 0, 0),
	-- 	BorderSizePixel = 0,
	-- },

	-- CanvasGroup = {
	-- 	BackgroundColor3 = Color3.new(1, 1, 1),
	-- 	BorderColor3 = Color3.new(0, 0, 0),
	-- 	BorderSizePixel = 0,
	-- },
}

-- Precompute default setters for speed
local defaultSetters = {}
for className, props in pairs(defaultProps) do
	defaultSetters[className] = function(instance)
		for k, v in pairs(props) do
			instance[k] = v
		end
	end
end

-- =========================================================
-- Lightweight Signal (faster than BindableEvent)
-- =========================================================
local function createSignal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			listeners[#listeners + 1] = fn
			return {
				Disconnect = function()
					for i = #listeners, 1, -1 do
						if listeners[i] == fn then
							table.remove(listeners, i)
							break
						end
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for _, fn in ipairs(listeners) do
				fn(...)
			end
		end,
	}
end

-- =========================================================
-- State
-- =========================================================
export type StateObject<T> = {
	_value: T,
	_changed: any,
	get: (self: StateObject<T>) -> T,
	set: (self: StateObject<T>, val: T) -> (),
	onChange: (self: StateObject<T>, fn: (T) -> ()) -> any,
}
export type State<T> = StateObject<T>

local currentTracker: { any }? = nil
local function isState(obj: any): boolean
	return typeof(obj) == "table" and obj.get and obj.set and obj.onChange ~= nil
end

local function state<T>(initial: T): State<T>
	local self = { _value = initial, _changed = createSignal() }

	function self:get(): T
		if currentTracker then
			currentTracker[#currentTracker + 1] = self
		end
		return self._value
	end

	function self:set(val: T)
		if self._value == val then
			return
		end
		if typeof(self._value) == "table" and typeof(val) == "table" then
			local changed = false
			for k, v in pairs(val) do
				if self._value[k] ~= v then
					changed = true
					break
				end
			end
			if not changed then
				return
			end
		end
		self._value = val
		self._changed:Fire(val)
	end

	function self:onChange(fn)
		return self._changed:Connect(fn)
	end

	return (self :: any) :: State<T>
end
Framework.State = state

-- =========================================================
-- Property Types
-- =========================================================
export type ReactiveValue =
	string
	| number
	| boolean
	| Color3
	| UDim2
	| Vector2
	| Rect
	| BrickColor
	| EnumItem
	| { [any]: any }
export type ReactiveProp<R = ReactiveValue> = R | State<R> | (() -> R)

export type PropertyTable<I = Instance> = {
	[string]: ReactiveProp<any>?,
	Children: { Instance | { Instance } }?,
	Ref: ((self: I) -> (() -> ())?)?,
	Draggable: boolean?,
	OnEnter: ((self: I) -> ())?,
	OnLeave: ((self: I) -> ())?,
	OnDown: ((self: I) -> ())?,
	OnUp: ((self: I) -> ())?,
	OnActivated: ((self: I) -> ())?,
	OnDragStart: ((self: I, startPos: UDim2, inputPos: Vector2) -> ())?,
	OnDrag: ((self: I, delta: Vector2, inputPos: Vector2) -> ())?,
	OnDragEnd: ((self: I, inputPos: Vector2) -> ())?,
}

export type Proxy<I> = I & (() -> I) -- TODO: Somehow the type for exposing the instance is not working

-- Full constructor overloads for better type inference
export type NewConstructor =
	((className: "Frame") -> (props: PropertyTable<Frame>) -> Proxy<Frame>)
	& ((className: "TextButton") -> (props: PropertyTable<TextButton>) -> Proxy<TextButton>)
	& ((className: "TextLabel") -> (props: PropertyTable<TextLabel>) -> Proxy<TextLabel>)
	& ((className: "ImageButton") -> (props: PropertyTable<ImageButton>) -> Proxy<ImageButton>)
	& ((className: "ImageLabel") -> (props: PropertyTable<ImageLabel>) -> Proxy<ImageLabel>)
	& ((className: "ScrollingFrame") -> (props: PropertyTable<ScrollingFrame>) -> Proxy<ScrollingFrame>)
	& ((className: "ViewportFrame") -> (props: PropertyTable<ViewportFrame>) -> Proxy<ViewportFrame>)
	& ((className: "CanvasGroup") -> (props: PropertyTable<CanvasGroup>) -> Proxy<CanvasGroup>)
	& ((className: "BillboardGui") -> (props: PropertyTable<BillboardGui>) -> Proxy<BillboardGui>)
	& ((className: "SurfaceGui") -> (props: PropertyTable<SurfaceGui>) -> Proxy<SurfaceGui>)
	& ((className: "ScreenGui") -> (props: PropertyTable<ScreenGui>) -> Proxy<ScreenGui>)
	& ((className: "TextBox") -> (props: PropertyTable<TextBox>) -> Proxy<TextBox>)
	& ((
		className: "UIAspectRatioConstraint"
	) -> (props: PropertyTable<UIAspectRatioConstraint>) -> Proxy<UIAspectRatioConstraint>)
	& ((className: "UICorner") -> (props: PropertyTable<UICorner>) -> Proxy<UICorner>)
	& ((className: "UIGradient") -> (props: PropertyTable<UIGradient>) -> Proxy<UIGradient>)
	& ((className: "UIGridLayout") -> (props: PropertyTable<UIGridLayout>) -> Proxy<UIGridLayout>)
	& ((className: "UIListLayout") -> (props: PropertyTable<UIListLayout>) -> Proxy<UIListLayout>)
	& ((className: "UIPadding") -> (props: PropertyTable<UIPadding>) -> Proxy<UIPadding>)
	& ((className: "UIScale") -> (props: PropertyTable<UIScale>) -> Proxy<UIScale>)
	& ((className: "UISizeConstraint") -> (props: PropertyTable<UISizeConstraint>) -> Proxy<UISizeConstraint>)
	& ((className: "UIStroke") -> (props: PropertyTable<UIStroke>) -> Proxy<UIStroke>)
	& ((className: "UITableLayout") -> (props: PropertyTable<UITableLayout>) -> Proxy<UITableLayout>)
	& ((className: "UITextSizeConstraint") -> (props: PropertyTable<UITextSizeConstraint>) -> Proxy<UITextSizeConstraint>)
	& ((className: string) -> (props: PropertyTable) -> Proxy<Instance>)

-- =========================================================
-- Children Updater with Diffing
-- =========================================================
local childCache = setmetatable({}, { __mode = "k" })

local function updateChildren(parent: Instance, newChildren: { any })
	local cache = childCache[parent] or {}
	local used = {}

	for i, child in ipairs(newChildren) do
		local inst = nil
		if typeof(child) == "table" and #child > 0 then
			updateChildren(parent, child)
		elseif typeof(child) == "userdata" or typeof(child) == "Instance" then
			inst = child
		elseif typeof(child) == "table" then
			local ok, result = pcall(child)
			if ok and typeof(result) == "Instance" then
				inst = result
			end
		end

		if inst then
			if inst.Parent ~= parent then
				inst.Parent = parent
			end
			if inst:IsA("GuiObject") then
				inst.LayoutOrder = i
			end
			used[inst] = true
		end
	end

	for inst in pairs(cache) do
		if not used[inst] then
			inst.Parent = nil
		end
	end

	childCache[parent] = used
end

-- =========================================================
-- Core Implementation
-- =========================================================
local function NewImpl(className: string)
	return function(props: PropertyTable<any>)
		local instance = Instance.new(className)
		local stateConnections: { [string]: any } = {}

		-- apply defaults
		local applyDefaults = defaultSetters[className]
		if applyDefaults then
			applyDefaults(instance)
		end

		-- proxy wrapper
		local proxy = {}
		local mt = {}
		setmetatable(proxy, mt)

		-- children reactivity
		local function applyChildren(val: any)
			if typeof(val) == "function" then
				local deps = {}
				local function run()
					for _, conn in ipairs(deps) do
						conn:Disconnect()
					end
					deps = {}
					local touched = {}
					currentTracker = touched
					local result = val()
					currentTracker = nil
					updateChildren(instance, result or {})
					for _, st in ipairs(touched) do
						deps[#deps + 1] = st:onChange(run)
					end
				end
				run()
			elseif isState(val) then
				local function apply(newVal)
					updateChildren(instance, newVal or {})
				end
				apply(val:get())
				val:onChange(apply)
			elseif val then
				updateChildren(instance, val)
			end
		end

		mt.__index = function(_, k)
			return instance[k]
		end
		mt.__newindex = function(_, k, v)
			if isState(v) then
				instance[k] = v:get()
				if stateConnections[k] then
					stateConnections[k]:Disconnect()
				end
				stateConnections[k] = v:onChange(function(newVal)
					instance[k] = newVal
				end)
			elseif typeof(v) == "function" and k ~= "Children" then
				local deps = {}
				local function run()
					for _, conn in ipairs(deps) do
						conn:Disconnect()
					end
					deps = {}
					local touched = {}
					currentTracker = touched
					local result = v()
					currentTracker = nil
					instance[k] = result
					for _, st in ipairs(touched) do
						deps[#deps + 1] = st:onChange(run)
					end
				end
				run()
			elseif k == "Children" then
				applyChildren(v)
			else
				instance[k] = v
			end
		end
		mt.__tostring = function()
			return instance:GetFullName()
		end
		mt.__eq = function(_, other)
			return other == instance or other == proxy
		end
		mt.__call = function()
			return instance
		end

		-- apply props
		for k, v in pairs(props) do
			if k == "Ref" and typeof(v) == "function" then
				task.defer(function()
					local cleanup = v(proxy)
					if cleanup then
						instance.Destroying:Connect(cleanup)
					end
				end)
			elseif not (k == "Draggable" or k:match("^On")) then
				proxy[k] = v
			end
		end

		-- events
		if props.OnEnter then
			instance.MouseEnter:Connect(function()
				props.OnEnter(proxy)
			end)
		end
		if props.OnLeave then
			instance.MouseLeave:Connect(function()
				props.OnLeave(proxy)
			end)
		end
		if instance:IsA("GuiButton") then
			if props.OnDown then
				instance.MouseButton1Down:Connect(function()
					props.OnDown(proxy)
				end)
			end
			if props.OnUp then
				instance.MouseButton1Up:Connect(function()
					props.OnUp(proxy)
				end)
			end
			if props.OnActivated then
				instance.Activated:Connect(function()
					props.OnActivated(proxy)
				end)
			end
		end

		-- dragging
		if props.Draggable or props.OnDrag or props.OnDragStart or props.OnDragEnd then
			local activeInput, dragConn
			instance.InputBegan:Connect(function(input)
				if activeInput then
					return
				end
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					activeInput = input
					local startPos = (instance :: GuiObject).Position
					local lastPos = input.Position
					if props.OnDragStart then
						props.OnDragStart(proxy, startPos, lastPos)
					end

					dragConn = UserInputService.InputChanged:Connect(function(move)
						if activeInput and move.Name == activeInput.Name then
							local currentPos = move.Position
							local delta = currentPos - lastPos
							lastPos = currentPos
							if props.Draggable and instance:IsA("GuiObject") then
								(instance :: GuiObject).Position = UDim2.new(
									startPos.X.Scale,
									startPos.X.Offset + (currentPos.X - input.Position.X),
									startPos.Y.Scale,
									startPos.Y.Offset + (currentPos.Y - input.Position.Y)
								)
							end
							if props.OnDrag then
								props.OnDrag(proxy, delta, currentPos)
							end
						end
					end)

					input.Changed:Connect(function()
						if input.UserInputState == Enum.UserInputState.End and activeInput == input then
							if dragConn then
								dragConn:Disconnect()
								dragConn = nil
							end
							activeInput = nil
							if props.OnDragEnd then
								props.OnDragEnd(proxy, lastPos)
							end
						end
					end)
				end
			end)
		end

		-- cleanup
		instance.Destroying:Connect(function()
			for _, conn in pairs(stateConnections) do
				conn:Disconnect()
			end
			stateConnections = {}
		end)

		return (proxy :: any) :: Proxy<any>
	end
end

Framework.New = (NewImpl :: any) :: NewConstructor

-- =========================================================
-- Helpers
-- =========================================================
function Framework.Map<T>(array: { T }, render: (item: T, index: number) -> Instance)
	local results = {}
	for i, item in ipairs(array) do
		local child = render(item, i)
		child.LayoutOrder = i
		results[i] = child
	end
	return results
end

return Framework
