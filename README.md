<img width="365" height="100" alt="katalyst" src="https://github.com/user-attachments/assets/879a731e-3c02-45d8-9508-e45de53428f9" />

# **🔥Katalyst – A simple & small but powerful ui framework**

Yo! I cooked up something called **Katalyst**  a simple & small UI framework that makes building reactive GUIs way less painful. No more spaghetti signal connections or fighting with layout.

---

[Documentation Website](https://katalyst.miukyo.my.id) - For more information

**🧩 Core Idea**

Katalyst wraps Roblox ui instances in a **proxy** so you can:

* Bind properties directly to **state**
* React to changes with **computed props** (functions)
* Manage **children** declaratively
* Hook into events with a clean `self` (the proxy, not just the raw instance)

Think of it like Roact/Fusion, but lean and without the ceremony.

---

## **Features**

### 1. Reactive State 🔎
```luau
local State = Katalyst.State
local New = Katalyst.New

local count = State(0)

local label = New("TextLabel")({
	Text = function()
		return "Count: " .. count:get()
	end,
})

count:set(count:get() + 1)
```
Change the state, UI updates. Easy.

### 2. Events, but cleaner ✨
```luau
local New = Katalyst.New

local button = New("TextButton")({
	Text = "Click Me",
	OnActivated = function(self)
		self.Text = "Clicked!"
	end,
})
```

If you ever need the **raw Roblox instance**, just call `self()`.

```luau
OnEnter = function(self)
	TweenService:Create(self(), TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { BackgroundTransparency = 0.5 }):Play()
end
```

### 3. Drag it 👌
Any UI object can be made draggable in one line:
```luau
local New = Katalyst.New

local window = New("Frame")({
	Draggable = true,
	OnDragEnd = function(self, pos)
		print("Dropped at", pos)
	end,
})
```

### 4. Mapping made easy 🗺️
Say goodbye to manual looping. Katalyst comes with a **`Map` helper**:
```luau
local New = Katalyst.New
local Map = Katalyst.Map

local items = { "One", "Two", "Three" }

local list = New("Frame")({
	Children = {
		New("UIListLayout")({}),
		Map(items, function(item, i)
			return New("TextLabel")({
				Text = i .. ". " .. item,
			})
		end),
	},
})
```

It automatically sets `LayoutOrder` for you, so the order just works™.

### 5. Refs for control 🎯
Need to grab your component or run cleanup when it’s destroyed? Use **`Ref`**:
```luau
local New = Katalyst.New

local box = New("TextBox")({
	Ref = function(self)
		-- self is the proxy
		self.Text = "Hello world!"

		-- optional cleanup when instance is destroyed
		return function()
			print("TextBox destroyed!")
		end
	end,
})
```


### 6. Still just an Instance 🏗️
Even though you interact with components through the proxy, under the hood they’re **real Roblox Instances**.
That means you can still do:
```luau
local frame = New("Frame")({})
local raw: Frame = frame() -- You need to manually add the type (Luau Limitation)

raw:Destroy() -- works fine
(frame()::Frame):Clone()   -- also fine
frame():AddTag() -- you lost the autocomplete
```

### 7. Works with Hoarcekat 🖼️
Katalyst plays nice with **Hoarcekat**, so you can build out components in isolation and preview them instantly.
Just return your Katalyst UI from a story file and it works:
```luau
return function(target)
	return New("TextLabel")({
		Parent = target,
		Text = "Hello from Katalyst in Hoarcekat!",
	})
end

-- or
local Label = New("TextLabel")({
	Text = "Hello from Katalyst in Hoarcekat!",
})
return function(target)
	Label.Parent = target
end
```

**💡 Why use Katalyst?**
* Less boilerplate
* Reactive props without glue code
* Clean event API with proxy `self`
* Call `self()` if you need the raw instance
* Still a normal `Instance`, so `:Destroy()`, `:Clone()`, `Tween*` all work
* Built-in drag handling
* Easy `.Map` for lists
* `Ref` for mount logic & cleanup
* The code are just 518 line long

**Ready to try? Get the model here**
[https://create.roblox.com/store/asset/102585843889477/Katalyst](https://create.roblox.com/store/asset/102585843889477/Katalyst)
