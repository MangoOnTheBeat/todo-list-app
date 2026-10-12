-- Kaido Drift UI kit: frosted glass on a blurred world, gradient accents, springy motion.
-- Panels are translucent cards with bright glass edges; buttons grow on hover, squish when pressed and
-- spring back; screens slide and fade in with an overshoot; chips and knobs bounce.
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Ui = {}

Ui.INK = Color3.fromHex("0c0d16")
Ui.PANEL = Color3.fromHex("141628")
Ui.TEXT = Color3.fromHex("f6f3ee")
Ui.DIM = Color3.fromHex("b3b0c4")
Ui.SAKURA = Color3.fromHex("ff7eb6")
Ui.VIOLET = Color3.fromHex("a77bff")
Ui.NEON = Color3.fromHex("59e3ff")
Ui.GOLD = Color3.fromHex("ffc94d")
Ui.DANGER = Color3.fromHex("ff5a5a")
Ui.LINE = Color3.new(1, 1, 1)

local okBody, body = pcall(function() return Font.fromEnum(Enum.Font.TitilliumWeb) end)
if not okBody then body = Font.fromEnum(Enum.Font.Gotham) end
local okDisp, disp = pcall(function() return Font.fromEnum(Enum.Font.GothamBlack) end)
if not okDisp then disp = body end
Ui.BODY = Font.new(body.Family, Enum.FontWeight.SemiBold)
Ui.BOLD = Font.new(body.Family, Enum.FontWeight.Bold)
Ui.DISPLAY = Font.new(disp.Family, Enum.FontWeight.Heavy)

function Ui.make(class, props, children)
	local o = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then (o :: any)[k] = v end
	end
	for _, c in children or {} do c.Parent = o end
	if props.Parent then o.Parent = props.Parent end
	return o
end
local make = Ui.make

-- motion
local SPRING = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ELASTIC = TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
function Ui.tween(o, props, info) local t = TweenService:Create(o, info or SPRING, props); t:Play(); return t end
local function scaleOf(o)
	local s = o:FindFirstChildOfClass("UIScale")
	if not s then s = make("UIScale", { Scale = 1, Parent = o }) end
	return s
end
-- a quick pop: grow, then spring back
function Ui.pop(o, amount)
	local s = scaleOf(o)
	s.Scale = amount or 1.18
	Ui.tween(s, { Scale = 1 }, ELASTIC)
end
-- buttons: grow on hover, squish on press, spring back on release
function Ui.bouncy(b)
	local s = scaleOf(b)
	b.MouseEnter:Connect(function() Ui.tween(s, { Scale = 1.035 }) end)
	b.MouseLeave:Connect(function() Ui.tween(s, { Scale = 1 }) end)
	b.MouseButton1Down:Connect(function() Ui.tween(s, { Scale = 0.94 }, QUICK) end)
	b.MouseButton1Up:Connect(function() Ui.tween(s, { Scale = 1 }, ELASTIC) end)
	b.InputBegan:Connect(function(io) if io.UserInputType == Enum.UserInputType.Touch then Ui.tween(s, { Scale = 0.94 }, QUICK) end end)
	b.InputEnded:Connect(function(io) if io.UserInputType == Enum.UserInputType.Touch then Ui.tween(s, { Scale = 1 }, ELASTIC) end end)
	return b
end

function Ui.corner(r) return make("UICorner", { CornerRadius = UDim.new(0, r or 12) }) end
function Ui.pad(l, t, r, b)
	return make("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l) })
end
function Ui.list(gap, horizontal, align)
	return make("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical, VerticalAlignment = align or Enum.VerticalAlignment.Top })
end
-- a bright glass edge: strongest at the top-left, fading round the panel
function Ui.edge(t, alpha)
	return make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = t or 1.2, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, {
		make("UIGradient", { Rotation = 45, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, alpha or 0.45), NumberSequenceKeypoint.new(0.5, 0.88), NumberSequenceKeypoint.new(1, 0.7) }) }),
	})
end
Ui.stroke = function(color, t, transp)
	return make("UIStroke", { Color = color or Ui.LINE, Thickness = t or 1, Transparency = transp or 0.85, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
-- turn a frame into frosted glass
function Ui.glass(f, radius, strength)
	f.BackgroundColor3 = Color3.fromHex("1a1d36")
	f.BackgroundTransparency = strength or 0.38
	f.BorderSizePixel = 0
	make("UICorner", { CornerRadius = UDim.new(0, radius or 18), Parent = f })
	make("UIGradient", { Rotation = 100, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 160, 210)), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.25) }), Parent = f })
	Ui.edge(1.2).Parent = f
	return f
end

-- text with automatic height (wraps to its width)
function Ui.text(props)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or Ui.TEXT
	props.FontFace = props.FontFace or Ui.BODY
	props.TextSize = props.TextSize or 16
	props.TextWrapped = props.TextWrapped ~= false
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.Size = props.Size or UDim2.new(1, 0, 0, 0)
	if props.AutomaticSize == nil then props.AutomaticSize = Enum.AutomaticSize.Y end
	props.RichText = true
	return make("TextLabel", props)
end
function Ui.eyebrow(t, order, parent)
	return Ui.text({ Text = string.upper(t), TextSize = 12, TextColor3 = Ui.DIM, FontFace = Ui.BOLD, LayoutOrder = order, Parent = parent })
end
function Ui.fine(t, order, parent)
	return Ui.text({ Text = t, TextSize = 13, TextColor3 = Ui.DIM, LineHeight = 1.25, LayoutOrder = order, Parent = parent })
end

-- the world behind menus goes soft
local blur = Lighting:FindFirstChild("KaidoBlur") or make("BlurEffect", { Name = "KaidoBlur", Size = 0, Parent = Lighting })
function Ui.blur(on) Ui.tween(blur, { Size = on and 18 or 0 }, TweenInfo.new(0.35, Enum.EasingStyle.Quad)) end

-- a floating glass card on the left with a scrolling column (every menu screen)
function Ui.sheet(gui, wide)
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
	local w = wide and 640 or 480
	local card = make("CanvasGroup", { Size = UDim2.new(0, w, 1, -40), Position = UDim2.new(0, 20, 0, 20), BackgroundTransparency = 1, Parent = root })
	local glassF = make("Frame", { Size = UDim2.fromScale(1, 1), Parent = card })
	Ui.glass(glassF, 24, 0.3)
	-- a soft sheen across the top of the glass
	make("Frame", { Size = UDim2.new(1, 0, 0, 160), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = glassF }, {
		make("UICorner", { CornerRadius = UDim.new(0, 24) }),
		make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.2, 1) }),
	})
	local scroll = make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Ui.DIM,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = card,
	}, { Ui.pad(28, 30, 28, 30), Ui.list(18) })
	local function fit()
		local vw = gui.AbsoluteSize.X
		local ww = math.min(w, vw - 24)
		card.Size = UDim2.new(0, ww, 1, -40)
		card.Position = UDim2.new(0, math.min(20, (vw - ww) / 2), 0, 20)
		card:SetAttribute("Home", card.Position)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	root:SetAttribute("Card", true)
	return root, scroll, card
end
-- slide and fade a screen in with an overshoot
function Ui.show(root)
	root.Visible = true
	local card = root:FindFirstChildOfClass("CanvasGroup")
	if card then
		local x = card:GetAttribute("Home") or card.Position
		card.GroupTransparency = 1
		card.Position = x + UDim2.new(0, -60, 0, 0)
		Ui.tween(card, { GroupTransparency = 0 }, TweenInfo.new(0.25, Enum.EasingStyle.Quad))
		Ui.tween(card, { Position = x }, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
		local s = scaleOf(card)
		s.Scale = 0.96
		Ui.tween(s, { Scale = 1 }, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	end
end

function Ui.heading(t, jp, order, parent)
	return Ui.text({ Text = t .. (jp and ('  <font color="#ff7eb6" size="20">' .. jp .. "</font>") or ""), FontFace = Ui.DISPLAY, TextSize = 36, LayoutOrder = order, Parent = parent })
end

-- a menu button: label left, small note right; primary = pink-violet gradient
function Ui.button(label, note, kind, order, parent)
	local primary, ghost = kind == "primary", kind == "ghost"
	local b = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 58), AutoButtonColor = false, Text = "", LayoutOrder = order, Parent = parent,
		BackgroundColor3 = primary and Color3.new(1, 1, 1) or Color3.fromHex("2a2e52"), BackgroundTransparency = primary and 0 or (ghost and 1 or 0.45),
	}, { make("UICorner", { CornerRadius = UDim.new(0, 16) }) })
	if primary then
		make("UIGradient", { Rotation = 0, Color = ColorSequence.new(Ui.SAKURA, Ui.VIOLET), Parent = b })
		make("UIStroke", { Color = Color3.fromHex("ffd1e6"), Thickness = 1.5, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	else
		Ui.edge(1).Parent = b
	end
	local lab = Ui.text({ Text = string.upper(label), FontFace = Ui.BOLD, TextSize = 16, TextColor3 = primary and Color3.new(1, 1, 1) or Ui.TEXT, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.55, -20, 1, 0), Position = UDim2.new(0, 20, 0, 0), TextWrapped = false, Parent = b })
	lab.Name = "Label"
	if note then
		local n = Ui.text({ Text = note, TextSize = 13, TextColor3 = primary and Color3.fromHex("fff0f7") or Ui.DIM, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.45, -20, 1, 0), Position = UDim2.new(0.55, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = b })
		n.Name = "Note"
	end
	return Ui.bouncy(b)
end

-- pill chips; returns a setter for the selected value
function Ui.chips(options, current, onPick, order, parent)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	make("UIListLayout", { Padding = UDim.new(0, 8), FillDirection = Enum.FillDirection.Horizontal, Wraps = true, SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	local btns = {}
	local function set(v, animate)
		for val, b in btns do
			local on = val == v
			b.BackgroundTransparency = on and 0 or 0.55
			b.BackgroundColor3 = on and Color3.new(1, 1, 1) or Color3.fromHex("2a2e52")
			b.TextColor3 = on and Color3.new(1, 1, 1) or Ui.TEXT
			b.UIGradient.Enabled = on
			if on and animate then Ui.pop(b, 1.15) end
		end
	end
	for k, opt in options do
		local b = make("TextButton", {
			Size = UDim2.new(0, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = opt[2], FontFace = Ui.BOLD, TextSize = 14, AutoButtonColor = false,
			LayoutOrder = k, Parent = row,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), Ui.edge(1), Ui.pad(16, 0, 16, 0), make("UIGradient", { Color = ColorSequence.new(Ui.SAKURA, Ui.VIOLET), Enabled = false }) })
		btns[opt[1]] = b
		Ui.bouncy(b)
		b.Activated:Connect(function() set(opt[1], true); onPick(opt[1]) end)
	end
	set(current, false)
	return function(v) set(v, false) end
end

-- a slider with a glowing knob that bounces when grabbed
function Ui.slider(min, max, step, value, onChange, order, parent)
	local holder = make("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	local track = make("Frame", { Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 0.5, -4), BackgroundColor3 = Color3.fromHex("2a2e52"), BackgroundTransparency = 0.3, Parent = holder }, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track }, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIGradient", { Color = ColorSequence.new(Ui.SAKURA, Ui.VIOLET) }) })
	local knob = make("Frame", { Size = UDim2.new(0, 24, 0, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = track }, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Color = Ui.SAKURA, Thickness = 3, Transparency = 0.2 }),
	})
	local function show(v)
		local f = (v - min) / (max - min)
		fill.Size = UDim2.new(f, 0, 1, 0)
		knob.Position = UDim2.new(f, 0, 0.5, 0)
	end
	local dragging = nil
	local function at(x)
		local f = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local v = math.clamp(min + math.floor((f * (max - min)) / step + 0.5) * step, min, max)
		show(v)
		onChange(v)
	end
	holder.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			dragging = io; at(io.Position.X)
			Ui.tween(scaleOf(knob), { Scale = 1.35 })
		end
	end)
	UserInputService.InputChanged:Connect(function(io)
		if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io == dragging) then at(io.Position.X) end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io == dragging or (dragging and io.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
			Ui.tween(scaleOf(knob), { Scale = 1 }, ELASTIC)
		end
	end)
	show(value)
	return show
end

-- glass stat tiles ("12,400 CREDITS")
function Ui.stats(items, order, parent)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent }, { Ui.list(10, true) })
	local vals = {}
	for k, it in items do
		local tile = make("Frame", { Size = UDim2.new(1 / #items, -10 * (#items - 1) / #items, 1, 0), LayoutOrder = k, Parent = row }, { Ui.pad(14, 8, 14, 8), Ui.list(0) })
		Ui.glass(tile, 14, 0.55)
		vals[k] = Ui.text({ Text = "0", FontFace = Ui.DISPLAY, TextSize = 22, TextColor3 = it[2] or Ui.TEXT, TextWrapped = false, LayoutOrder = 1, Parent = tile })
		Ui.text({ Text = string.upper(it[1]), TextSize = 11, TextColor3 = Ui.DIM, FontFace = Ui.BOLD, TextWrapped = false, LayoutOrder = 2, Parent = tile })
	end
	return vals
end

function Ui.field(label, order, parent)
	local f = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = parent }, { Ui.list(8) })
	local l = Ui.eyebrow(label, 0, f)
	return f, l
end

function Ui.fmt(n)
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end

return Ui
