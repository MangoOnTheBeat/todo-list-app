-- Kaido Drift UI kit: the browser game's look in Roblox (dark sheet on the left, sakura-pink primary
-- buttons, neon data, gold money, uppercase letter-spaced labels, pill chips and sliders).
local UserInputService = game:GetService("UserInputService")

local Ui = {}

Ui.INK = Color3.fromHex("0c0d16")
Ui.PANEL = Color3.fromHex("151626")
Ui.TEXT = Color3.fromHex("f3efe7")
Ui.DIM = Color3.fromHex("a9a6b8")
Ui.SAKURA = Color3.fromHex("ff7eb6")
Ui.NEON = Color3.fromHex("59e3ff")
Ui.GOLD = Color3.fromHex("ffc94d")
Ui.DANGER = Color3.fromHex("ff5a5a")
Ui.LINE = Color3.new(1, 1, 1)

-- Titillium Web stands in for the browser's Chakra Petch; heavy Gotham for its Dela Gothic One
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

function Ui.corner(r) return make("UICorner", { CornerRadius = UDim.new(0, r or 4) }) end
function Ui.stroke(color, t, transp)
	return make("UIStroke", { Color = color or Ui.LINE, Thickness = t or 1, Transparency = transp or 0.87, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
function Ui.pad(l, t, r, b)
	return make("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l) })
end
function Ui.list(gap, horizontal, align)
	return make("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical, VerticalAlignment = align or Enum.VerticalAlignment.Top })
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

-- the left-hand sheet every menu screen uses: gradient panel with a scrolling column
function Ui.sheet(gui, wide)
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
	local w = wide and 640 or 480
	local bg = make("Frame", { Size = UDim2.new(0, w + 140, 1, 0), BackgroundColor3 = Color3.fromHex("0a0b14"), BorderSizePixel = 0, Parent = root }, {
		make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.72, 0.14), NumberSequenceKeypoint.new(1, 1) }) }),
		make("UISizeConstraint", { MaxSize = Vector2.new(math.huge, math.huge) }),
	})
	local scroll = make("ScrollingFrame", {
		Size = UDim2.new(0, w, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Ui.DIM,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = root,
	}, { Ui.pad(28, 28, 28, 28), Ui.list(18) })
	local function fit()
		local vw = gui.AbsoluteSize.X
		local ww = math.min(w, vw)
		scroll.Size = UDim2.new(0, ww, 1, 0)
		bg.Size = UDim2.new(0, math.min(ww + 140, vw), 1, 0)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return root, scroll
end

-- heading like "Garage ガレージ"
function Ui.heading(t, jp, order, parent)
	return Ui.text({ Text = t .. (jp and ('  <font color="#ff7eb6" size="20">' .. jp .. "</font>") or ""), FontFace = Ui.DISPLAY, TextSize = 34, LayoutOrder = order, Parent = parent })
end

-- a menu button: label on the left, small grey note on the right
function Ui.button(label, note, kind, order, parent)
	local primary, ghost = kind == "primary", kind == "ghost"
	local b = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 52), AutoButtonColor = false, Text = "", LayoutOrder = order, Parent = parent,
		BackgroundColor3 = primary and Ui.SAKURA or Color3.new(1, 1, 1), BackgroundTransparency = primary and 0 or (ghost and 1 or 0.96),
	}, { Ui.corner(4), Ui.stroke(primary and Ui.SAKURA or Ui.LINE, 1, primary and 0 or 0.87) })
	local lab = Ui.text({ Text = string.upper(label), FontFace = Ui.BOLD, TextSize = 15, TextColor3 = primary and Color3.fromHex("1a0b14") or Ui.TEXT, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.55, -18, 1, 0), Position = UDim2.new(0, 18, 0, 0), TextWrapped = false, Parent = b })
	lab.Name = "Label"
	if note then
		local n = Ui.text({ Text = note, TextSize = 13, TextColor3 = primary and Color3.fromHex("4a1d33") or Ui.DIM, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.45, -18, 1, 0), Position = UDim2.new(0.55, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = b })
		n.Name = "Note"
	end
	b.MouseEnter:Connect(function() if not primary then b.BackgroundTransparency = 0.91 end end)
	b.MouseLeave:Connect(function() if not primary then b.BackgroundTransparency = ghost and 1 or 0.96 end end)
	return b
end

-- a row of pill chips; returns a setter for the selected value
function Ui.chips(options, current, onPick, order, parent)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	make("UIListLayout", { Padding = UDim.new(0, 8), FillDirection = Enum.FillDirection.Horizontal, Wraps = true, SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	local btns = {}
	local function set(v)
		for val, b in btns do
			local on = val == v
			b.BackgroundColor3 = on and Ui.SAKURA or Color3.new(1, 1, 1)
			b.BackgroundTransparency = on and 0 or 0.95
			b.TextColor3 = on and Color3.fromHex("1a0b14") or Ui.TEXT
		end
	end
	for k, opt in options do
		local b = make("TextButton", {
			Size = UDim2.new(0, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = opt[2], FontFace = Ui.BOLD, TextSize = 14, AutoButtonColor = false,
			LayoutOrder = k, Parent = row,
		}, { make("UICorner", { CornerRadius = UDim.new(0, 20) }), Ui.stroke(Ui.LINE, 1, 0.87), Ui.pad(14, 0, 14, 0) })
		btns[opt[1]] = b
		b.Activated:Connect(function() set(opt[1]); onPick(opt[1]) end)
	end
	set(current)
	return set
end

-- a slider (pink fill); onChange gets the stepped value
function Ui.slider(min, max, step, value, onChange, order, parent)
	local holder = make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	local track = make("Frame", { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.5, -3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, Parent = holder }, { Ui.corner(3) })
	local fill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Ui.SAKURA, Parent = track }, { Ui.corner(3) })
	local knob = make("Frame", { Size = UDim2.new(0, 20, 0, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Ui.SAKURA, Parent = track }, { Ui.corner(10) })
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
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then dragging = io; at(io.Position.X) end
	end)
	UserInputService.InputChanged:Connect(function(io)
		if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io == dragging) then at(io.Position.X) end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io == dragging or (dragging and io.UserInputType == Enum.UserInputType.MouseButton1) then dragging = nil end
	end)
	show(value)
	return show
end

-- "0  CREDITS" stat columns
function Ui.stats(items, order, parent)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent }, { Ui.list(22, true) })
	local vals = {}
	for k, it in items do
		local col = make("Frame", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = k, Parent = row }, { Ui.list(0) })
		vals[k] = Ui.text({ Text = "0", FontFace = Ui.BOLD, TextSize = 22, TextColor3 = it[2] or Ui.TEXT, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), TextWrapped = false, LayoutOrder = 1, Parent = col })
		Ui.text({ Text = string.upper(it[1]), TextSize = 11, TextColor3 = Ui.DIM, FontFace = Ui.BOLD, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), TextWrapped = false, LayoutOrder = 2, Parent = col })
	end
	return vals
end

-- a labelled group (eyebrow + contents)
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
