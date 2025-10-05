local UserInputService = game:GetService("UserInputService")

local Framework = {}

-- =========================================================
-- Update Batching System
-- =========================================================
local updateQueue = {}
local isScheduled = false

local function flushUpdates()
	isScheduled = false
	local toUpdate = updateQueue
	updateQueue = {}

	for fn in pairs(toUpdate) do
		local ok, err = pcall(fn)
		if not ok then
			warn("Error in batched update:", err)
		end
	end
end

local function scheduleUpdate(fn)
	updateQueue[fn] = true
	if not isScheduled then
		isScheduled = true
		task.defer(flushUpdates)
	end
end

-- =========================================================
-- Default Props
-- =========================================================
local defaultProps = {
	ScreenGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	},

	BillboardGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Active = true,
	},

	SurfaceGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
	},

	Frame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
	},

	ScrollingFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ScrollBarImageColor3 = Color3.new(0, 0, 0),
	},

	TextLabel = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSans,
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14,
	},

	TextButton = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.SourceSans,
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14,
	},

	TextBox = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.SourceSans,
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14,
	},

	ImageLabel = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
	},

	ImageButton = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		AutoButtonColor = false,
	},

	ViewportFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
	},

	VideoFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
	},

	CanvasGroup = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
	},
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
	get: (StateObject<T>) -> T,
	set: (StateObject<T>, val: T) -> (),
	onChange: (StateObject<T>, fn: (T) -> ()) -> any,
	destroy: (StateObject<T>) -> (),
}
export type State<T> = StateObject<T>

local stateCleanupRegistry = setmetatable({}, { __mode = "k" })

local function isState(obj: any): boolean
	return typeof(obj) == "table" and obj.get and obj.set and obj.onChange ~= nil
end

local function state<T>(initial: T): State<T>
	local stateObj = {
		_value = initial,
		_changed = createSignal(),
	}

	function stateObj.get(self): T
		return self._value
	end

	function stateObj.set(self, val: T)
		-- Better equality check
		if self._value == val then
			return
		end

		-- Deep comparison for tables
		if typeof(self._value) == "table" and typeof(val) == "table" then
			local function deepEquals(a, b)
				if a == b then
					return true
				end
				if typeof(a) ~= typeof(b) then
					return false
				end
				if typeof(a) ~= "table" then
					return false
				end

				for k, v in pairs(a) do
					if not deepEquals(v, b[k]) then
						return false
					end
				end
				for k in pairs(b) do
					if a[k] == nil then
						return false
					end
				end
				return true
			end

			if deepEquals(self._value, val) then
				return
			end
		end

		self._value = val
		scheduleUpdate(function()
			self._changed:Fire(val)
		end)
	end

	function stateObj.onChange(self, fn)
		return self._changed:Connect(fn)
	end

	function stateObj.destroy(self)
		if self._changed then
			-- Disconnect all listeners
			self._changed = createSignal() -- Reset signal
		end
		stateCleanupRegistry[self] = nil
	end

	-- Register for cleanup tracking
	stateCleanupRegistry[stateObj] = true

	return (stateObj :: any) :: State<T>
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

export type Proxy<I> = (() -> I) & I

-- Base property table for all instances
export type BasePropertyTable<I = Instance> = {
	[string]: ReactiveProp<any>?,
	Children: { Instance | { Instance } }?,
	Ref: ((self: Proxy<I>) -> (() -> ())?)?,
	Draggable: boolean?,
	OnEnter: ((self: Proxy<I>) -> ())?,
	OnLeave: ((self: Proxy<I>) -> ())?,
	OnDragStart: ((self: Proxy<I>, startPos: UDim2, inputPos: Vector2) -> ())?,
	OnDrag: ((self: Proxy<I>, delta: Vector2, inputPos: Vector2) -> ())?,
	OnDragEnd: ((self: Proxy<I>, inputPos: Vector2) -> ())?,
}

-- Extended property table for GuiButton instances
export type ButtonPropertyTable<I = GuiButton> = BasePropertyTable<I> & {
	OnDown: ((self: Proxy<I>) -> ())?,
	OnUp: ((self: Proxy<I>) -> ())?,
	OnActivated: ((self: Proxy<I>) -> ())?,
}

-- Main property table type (defaults to base)
export type PropertyTable<I = Instance> = BasePropertyTable<I>

-- Full constructor overloads for better type inference
export type NewConstructor =
	((className: "Frame") -> (props: PropertyTable<Frame>) -> Proxy<Frame>)
	& ((className: "TextButton") -> (props: ButtonPropertyTable<TextButton>) -> Proxy<TextButton>)
	& ((className: "TextLabel") -> (props: PropertyTable<TextLabel>) -> Proxy<TextLabel>)
	& ((className: "ImageButton") -> (props: ButtonPropertyTable<ImageButton>) -> Proxy<ImageButton>)
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
local childCleanupConnections = setmetatable({}, { __mode = "k" })

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

	-- Setup cleanup for parent destruction
	if not childCleanupConnections[parent] then
		childCleanupConnections[parent] = parent.Destroying:Connect(function()
			childCache[parent] = nil
			childCleanupConnections[parent] = nil
		end)
	end
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
				local function run()
					local result = val()
					updateChildren(instance, result or {})
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
				local result = v()
				instance[k] = result
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
				props.OnEnter(proxy :: any)
			end)
		end
		if props.OnLeave then
			instance.MouseLeave:Connect(function()
				props.OnLeave(proxy :: any)
			end)
		end
		if instance:IsA("GuiButton") then
			if props.OnDown and typeof(props.OnDown) == "function" then
				instance.MouseButton1Down:Connect(function()
					(props.OnDown :: any)(proxy :: any)
				end)
			end
			if props.OnUp and typeof(props.OnUp) == "function" then
				instance.MouseButton1Up:Connect(function()
					(props.OnUp :: any)(proxy :: any)
				end)
			end
			if props.OnActivated and typeof(props.OnActivated) == "function" then
				instance.Activated:Connect(function()
					(props.OnActivated :: any)(proxy :: any)
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
						props.OnDragStart(proxy :: any, startPos, lastPos)
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
								props.OnDrag(proxy :: any, delta, currentPos)
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
								props.OnDragEnd(proxy :: any, lastPos)
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

-- Error boundary (now that Framework.New is defined)
local function createErrorBoundary(fallbackComponent)
	return function(component)
		return function(props)
			local ok, result = pcall(component, props)
			if ok then
				return result
			else
				warn("Component error:", result)
				if fallbackComponent then
					return fallbackComponent(props, result)
				end
				return Framework.New("TextLabel")({
					Text = game:GetService("RunService"):IsStudio() and ("Error: " .. tostring(result))
						or "Component Error",
					TextColor3 = Color3.new(1, 0, 0),
					BackgroundColor3 = Color3.new(1, 1, 1),
					Size = UDim2.new(1, 0, 0, 50),
				})
			end
		end
	end
end

Framework.ErrorBoundary = createErrorBoundary

-- =========================================================
-- Fragment Component
-- =========================================================
function Framework.Fragment(render: () -> { Instance }): { Instance }
	return render()
end

-- =========================================================
-- Map Component
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
