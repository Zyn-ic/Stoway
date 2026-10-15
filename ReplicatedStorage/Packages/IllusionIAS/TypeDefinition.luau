--!strict
--TypeDefinition.luau
--[[
  //////////////////////
 // Type Declaration //
//////////////////////
]]

export type variant = boolean | number | Vector2 | Vector3

export type func<T = variant> = (active: T, pressed: boolean?) -> ()

export type IAScriptConnection = {
	Connected: boolean,
	Disconnect: (self: IAScriptConnection) -> (),
}

export type IAScriptSignal<T = variant> = {
	Connect: (self: IAScriptSignal<T>, fn: func<T>) -> IAScriptConnection,
	Once: (self: IAScriptSignal<T>, fn: func<T>) -> IAScriptConnection,
	Fire: (self: IAScriptSignal<T>, active: T, pressed: boolean?) -> (),
	Wait: (self: IAScriptSignal<T>) -> (T, boolean?),
	DisconnectAll: (self: IAScriptSignal<T>) -> (),
}

export type Node<T = variant> = {
	fn: func<T>?,
	next: Node<T>?,
	prev: Node<T>?,
}

export type supposedKeyCode = Enum.KeyCode | string

export type Bind = {
	KeyCode: Enum.KeyCode,
	PrimaryModifier: Enum.KeyCode,
	SecondaryModifier: Enum.KeyCode,
	UIButton: GuiButton?,
	UIModifier: GuiButton?,
	DisplayName: string?,
	DisplayImage: Content?,
	Type: Enum.InputBindingType?,
}

export type Binds = {
	[string]: Bind
}

export type DiffList = {
	BindName: string,
	ChangeType: string,
	OldKeyCode: Enum.KeyCode,
	NewKeyCode: Enum.KeyCode,
	OldModifiers: { PrimaryModifier: Enum.KeyCode, SecondaryModifier: Enum.KeyCode },
	NewModifiers: { PrimaryModifier: Enum.KeyCode, SecondaryModifier: Enum.KeyCode },
	AddedModifiers: { PrimaryModifier: Enum.KeyCode, SecondaryModifier: Enum.KeyCode },
	RemovedModifiers: { PrimaryModifier: Enum.KeyCode, SecondaryModifier: Enum.KeyCode },
	UIButton: GuiButton?,
	UIModifier: GuiButton?,
	DisplayName: string?,
	DisplayImage: Content?,
	BindingType: Enum.InputBindingType?,
}

export type BindingObject<T = variant> = {
	Name: string,

	Hold: boolean,

	Binds: Binds,

	UIButton: GuiButton?,
	UIModifier: GuiButton?,

	Active: T,

	Enabled: boolean,
	Priority: number,
	Sink: boolean,

	Scale: number,
	VectorScale: Vector2 | Vector3,
	ResponseCurve: number,

	PointerIndex: number,
	ClampMagnitudeToOne: boolean,

	PressedThreshold: number,
	ReleasedThreshold: number,

	Cooldown: number,

	TapRequired: number,
	TapWindow: number,

	InputBufferEnabled: boolean,
	InputBufferTime: number,

	Activated: IAScriptSignal<T>,
	Started: IAScriptSignal<T>,
	Ended: IAScriptSignal<T>,

	Fire: (self: BindingObject<T>, active: T, pressed: boolean) -> (),

	SetHold: (self: BindingObject<T>, bool: boolean) -> (),
	SetUIButton: (self: BindingObject<T>, button: GuiButton?) -> (),
	SetUIModifier: (self: BindingObject<T>, button: GuiButton?) -> (),
	GetUIModifier: (self: BindingObject<T>) -> GuiButton?,
	SetTapActivation: (self: BindingObject<T>, requiredTaps: number, tapWindow: number) -> (),
	SetCooldown: (self: BindingObject<T>, cooldown: number) -> (),
	ResetCooldown: (self: BindingObject<T>) -> (),
	CooldownEnded: (self: BindingObject<T>) -> boolean,

	SetEnabled: (self: BindingObject<T>, bool: boolean) -> (),
	IsEnabled: (self: BindingObject<T>) -> boolean,

	SetPriority: (self: BindingObject<T>, number: number) -> (),
	GetPriority: (self: BindingObject<T>) -> number,

	SetSink: (self: BindingObject<T>, bool: boolean) -> (),
	GetSink: (self: BindingObject<T>) -> boolean,

	SetScale: (self: BindingObject<T>, scale: number) -> (),
	GetScale: (self: BindingObject<T>) -> number,

	SetVectorScale: (self: BindingObject<T>, vector: Vector2 | Vector3) -> (),
	GetVectorScale: (self: BindingObject<T>) -> Vector2 | Vector3,

	SetResponseCurve: (self: BindingObject<T>, curve: number) -> (),
	GetResponseCurve: (self: BindingObject<T>) -> number,

	SetPressedThreshold: (self: BindingObject<T>, threshold: number) -> (),
	GetPressedThreshold: (self: BindingObject<T>) -> number,

	SetReleasedThreshold: (self: BindingObject<T>, threshold: number) -> (),
	GetReleasedThreshold: (self: BindingObject<T>) -> number,

	SetPointerIndex: (self: BindingObject<T>, index: number) -> (),
	GetPointerIndex: (self: BindingObject<T>) -> number,

	SetClampMagnitudeToOne: (self: BindingObject<T>, bool: boolean) -> (),
	GetClampMagnitudeToOne: (self: BindingObject<T>) -> boolean,

	GetState: (self: BindingObject<T>) -> T,

	SetInputBufferEnabled: (self: BindingObject<T>, bool: boolean) -> (),
	SetInputBufferTime: (self: BindingObject<T>, t: number) -> (),

	GetBinds: (self: BindingObject<T>) -> Binds,

	GetCooldownRemaining: (self: BindingObject<T>) -> number,
	IsBuffered: (self: BindingObject<T>) -> boolean,
	ResetBuffer: (self: BindingObject<T>) -> (),
	GetBufferedVariant: (self: BindingObject<T>) -> T?,
	GetBufferedKey: (self: BindingObject<T>) -> Enum.KeyCode,
	GetActiveBindCount: (self: BindingObject<T>) -> number,
	GetToggleState: (self: BindingObject<T>) -> boolean,
	GetActiveMainKey: (self: BindingObject<T>) -> Enum.KeyCode,

	AddBind: (
		self: BindingObject<T>,
		mainKey: supposedKeyCode,
		PrimaryModifier: supposedKeyCode?,
		SecondaryModifier: supposedKeyCode?,
		UIButton: GuiButton?,
		UIModifier: GuiButton?,
		DisplayName: string?,
		DisplayImage: Content?,
		BindingType: Enum.InputBindingType?
	) -> (),
	SetBind: (
		self: BindingObject<T>,
		mainKey: supposedKeyCode,
		PrimaryModifier: supposedKeyCode?,
		SecondaryModifier: supposedKeyCode?,
		UIButton: GuiButton?,
		UIModifier: GuiButton?,
		DisplayName: string?,
		DisplayImage: Content?,
		BindingType: Enum.InputBindingType?
	) -> (),
	SetAllBinds: (self: BindingObject<T>, Binds: Binds) -> (),
	RemoveBind: (self: BindingObject<T>, mainKey: supposedKeyCode, PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode?) -> (),
	EditBind: (
		self: BindingObject<T>,
		oldMain: supposedKeyCode,
		oldMods: { PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode? },
		newMain: supposedKeyCode,
		newMods: { PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode? }
	) -> (),
	SetDisplayName: (self: BindingObject<T>, mainKey: supposedKeyCode, displayName: string) -> boolean,
	GetDisplayName: (self: BindingObject<T>, mainKey: supposedKeyCode) -> string?,
	SetDisplayImage: (self: BindingObject<T>, mainKey: supposedKeyCode, displayImage: Content) -> boolean,
	GetDisplayImage: (self: BindingObject<T>, mainKey: supposedKeyCode) -> Content?,
	SetBindingType: (self: BindingObject<T>, mainKey: supposedKeyCode, bindingType: Enum.InputBindingType) -> boolean,
	GetBindingType: (self: BindingObject<T>, mainKey: supposedKeyCode) -> Enum.InputBindingType?,
	ClearBinds: (self: BindingObject<T>) -> (),

	SetCompositeDirections: (
		self: BindingObject<T>,
		up: supposedKeyCode?,
		down: supposedKeyCode?,
		left: supposedKeyCode?,
		right: supposedKeyCode?,
		forward: supposedKeyCode?,
		backward: supposedKeyCode?
	) -> (),
	GetCompositeDirections: (self: BindingObject<T>) -> {
		Up: Enum.KeyCode,
		Down: Enum.KeyCode,
		Left: Enum.KeyCode,
		Right: Enum.KeyCode,
		Forward: Enum.KeyCode,
		Backward: Enum.KeyCode,
	},
	SetCompositeModifiers: (self: BindingObject<T>, PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode?) -> (),
	GetCompositeModifiers: (self: BindingObject<T>) -> {
		PrimaryModifier: Enum.KeyCode,
		SecondaryModifier: Enum.KeyCode,
	},

	GetPreferredBinding: (self: BindingObject<T>) -> InputBinding?,
	GetInputAction: (self: BindingObject<T>) -> InputAction?,
	GetInputContext: (self: BindingObject<T>) -> InputContext?,
	GetInputBinding: (self: BindingObject<T>, keyOrName: (supposedKeyCode | string)?) -> InputBinding?,
	CreateActionLabel: (self: BindingObject<T>, parent: Instance?) -> GuiObject?,

	Destroy: (self: BindingObject<T>) -> boolean,
}

export type Context = { Enabled: boolean, Members: { [string]: boolean } }

export type Contexts = { [string]: Context }

export type IllusionIAS = {
	contextedBinds: Contexts,
	new: (name: string, inputType: Enum.InputActionType?) -> BindingObject,
	enableControlHints: (module: Instance | string, parent: Instance | PlayerGui?) -> ScreenGui,
	get: (name: string) -> BindingObject?,
	getAll: () -> { [string]: BindingObject },
	newContext: (name: string) -> (),
	getContext: (name: string) -> Context?,
	addContext: (name: string, ...BindingObject) -> (),
	enableContext: (name: string, enabled: boolean) -> (),
	isContextEnabled: (name: string) -> boolean,
	removeContext: (name: string) -> (),
	removeFromContext: (name: string, bind: BindingObject) -> (),
	removeAllFromContext: (name: string) -> (),
	clearContexts: () -> (),
}

local InputTypeByKey: { [Enum.KeyCode]: "Keyboard" | "Gamepad" | "Mobile" } = {
	-- Mouse & Pointer (IAS KeyCodes)
	[Enum.KeyCode.MouseLeftButton] = "Keyboard",
	[Enum.KeyCode.MouseRightButton] = "Keyboard",
	[Enum.KeyCode.MouseMiddleButton] = "Keyboard",
	[Enum.KeyCode.MousePosition] = "Keyboard",
	[Enum.KeyCode.MouseWheel] = "Keyboard",
	[Enum.KeyCode.MouseDelta] = "Keyboard",

	-- Trackpad Gestures (IAS KeyCodes)
	[Enum.KeyCode.TrackpadPan] = "Keyboard",
	[Enum.KeyCode.TrackpadPinch] = "Keyboard",

	-- Alphabet
	[Enum.KeyCode.A] = "Keyboard",
	[Enum.KeyCode.B] = "Keyboard",
	[Enum.KeyCode.C] = "Keyboard",
	[Enum.KeyCode.D] = "Keyboard",
	[Enum.KeyCode.E] = "Keyboard",
	[Enum.KeyCode.F] = "Keyboard",
	[Enum.KeyCode.G] = "Keyboard",
	[Enum.KeyCode.H] = "Keyboard",
	[Enum.KeyCode.I] = "Keyboard",
	[Enum.KeyCode.J] = "Keyboard",
	[Enum.KeyCode.K] = "Keyboard",
	[Enum.KeyCode.L] = "Keyboard",
	[Enum.KeyCode.M] = "Keyboard",
	[Enum.KeyCode.N] = "Keyboard",
	[Enum.KeyCode.O] = "Keyboard",
	[Enum.KeyCode.P] = "Keyboard",
	[Enum.KeyCode.Q] = "Keyboard",
	[Enum.KeyCode.R] = "Keyboard",
	[Enum.KeyCode.S] = "Keyboard",
	[Enum.KeyCode.T] = "Keyboard",
	[Enum.KeyCode.U] = "Keyboard",
	[Enum.KeyCode.V] = "Keyboard",
	[Enum.KeyCode.W] = "Keyboard",
	[Enum.KeyCode.X] = "Keyboard",
	[Enum.KeyCode.Y] = "Keyboard",
	[Enum.KeyCode.Z] = "Keyboard",

	-- Numbers
	[Enum.KeyCode.Zero] = "Keyboard",
	[Enum.KeyCode.One] = "Keyboard",
	[Enum.KeyCode.Two] = "Keyboard",
	[Enum.KeyCode.Three] = "Keyboard",
	[Enum.KeyCode.Four] = "Keyboard",
	[Enum.KeyCode.Five] = "Keyboard",
	[Enum.KeyCode.Six] = "Keyboard",
	[Enum.KeyCode.Seven] = "Keyboard",
	[Enum.KeyCode.Eight] = "Keyboard",
	[Enum.KeyCode.Nine] = "Keyboard",

	-- Keypad
	[Enum.KeyCode.KeypadZero] = "Keyboard",
	[Enum.KeyCode.KeypadOne] = "Keyboard",
	[Enum.KeyCode.KeypadTwo] = "Keyboard",
	[Enum.KeyCode.KeypadThree] = "Keyboard",
	[Enum.KeyCode.KeypadFour] = "Keyboard",
	[Enum.KeyCode.KeypadFive] = "Keyboard",
	[Enum.KeyCode.KeypadSix] = "Keyboard",
	[Enum.KeyCode.KeypadSeven] = "Keyboard",
	[Enum.KeyCode.KeypadEight] = "Keyboard",
	[Enum.KeyCode.KeypadNine] = "Keyboard",
	[Enum.KeyCode.KeypadPeriod] = "Keyboard",
	[Enum.KeyCode.KeypadDivide] = "Keyboard",
	[Enum.KeyCode.KeypadMultiply] = "Keyboard",
	[Enum.KeyCode.KeypadMinus] = "Keyboard",
	[Enum.KeyCode.KeypadPlus] = "Keyboard",
	[Enum.KeyCode.KeypadEnter] = "Keyboard",
	[Enum.KeyCode.KeypadEquals] = "Keyboard",

	-- Navigation & Arrows
	[Enum.KeyCode.Up] = "Keyboard",
	[Enum.KeyCode.Down] = "Keyboard",
	[Enum.KeyCode.Left] = "Keyboard",
	[Enum.KeyCode.Right] = "Keyboard",
	[Enum.KeyCode.Insert] = "Keyboard",
	[Enum.KeyCode.Delete] = "Keyboard",
	[Enum.KeyCode.Home] = "Keyboard",
	[Enum.KeyCode.End] = "Keyboard",
	[Enum.KeyCode.PageUp] = "Keyboard",
	[Enum.KeyCode.PageDown] = "Keyboard",

	-- Special & Modifiers
	[Enum.KeyCode.LeftShift] = "Keyboard",
	[Enum.KeyCode.RightShift] = "Keyboard",
	[Enum.KeyCode.LeftControl] = "Keyboard",
	[Enum.KeyCode.RightControl] = "Keyboard",
	[Enum.KeyCode.LeftAlt] = "Keyboard",
	[Enum.KeyCode.RightAlt] = "Keyboard",
	[Enum.KeyCode.LeftMeta] = "Keyboard",
	[Enum.KeyCode.RightMeta] = "Keyboard",
	[Enum.KeyCode.LeftSuper] = "Keyboard",
	[Enum.KeyCode.RightSuper] = "Keyboard",
	[Enum.KeyCode.Space] = "Keyboard",
	[Enum.KeyCode.Tab] = "Keyboard",
	[Enum.KeyCode.Return] = "Keyboard",
	[Enum.KeyCode.Backspace] = "Keyboard",
	[Enum.KeyCode.Escape] = "Keyboard",
	[Enum.KeyCode.CapsLock] = "Keyboard",
	[Enum.KeyCode.ScrollLock] = "Keyboard",
	[Enum.KeyCode.NumLock] = "Keyboard",
	[Enum.KeyCode.Pause] = "Keyboard",
	[Enum.KeyCode.Clear] = "Keyboard",
	[Enum.KeyCode.Print] = "Keyboard",
	[Enum.KeyCode.Menu] = "Keyboard",

	-- Punctuation & Symbols
	[Enum.KeyCode.Comma] = "Keyboard",
	[Enum.KeyCode.Period] = "Keyboard",
	[Enum.KeyCode.Slash] = "Keyboard",
	[Enum.KeyCode.Semicolon] = "Keyboard",
	[Enum.KeyCode.Quote] = "Keyboard",
	[Enum.KeyCode.LeftBracket] = "Keyboard",
	[Enum.KeyCode.RightBracket] = "Keyboard",
	[Enum.KeyCode.BackSlash] = "Keyboard",
	[Enum.KeyCode.Minus] = "Keyboard",
	[Enum.KeyCode.Equals] = "Keyboard",
	[Enum.KeyCode.Tilde] = "Keyboard",
	[Enum.KeyCode.Backquote] = "Keyboard",
	[Enum.KeyCode.QuotedDouble] = "Keyboard",
	[Enum.KeyCode.Hash] = "Keyboard",
	[Enum.KeyCode.Dollar] = "Keyboard",
	[Enum.KeyCode.Percent] = "Keyboard",
	[Enum.KeyCode.Ampersand] = "Keyboard",
	[Enum.KeyCode.LeftParenthesis] = "Keyboard",
	[Enum.KeyCode.RightParenthesis] = "Keyboard",
	[Enum.KeyCode.Asterisk] = "Keyboard",
	[Enum.KeyCode.Plus] = "Keyboard",
	[Enum.KeyCode.Colon] = "Keyboard",
	[Enum.KeyCode.LeftCurly] = "Keyboard",
	[Enum.KeyCode.RightCurly] = "Keyboard",
	[Enum.KeyCode.Caret] = "Keyboard",
	[Enum.KeyCode.Underscore] = "Keyboard",
	[Enum.KeyCode.Pipe] = "Keyboard",
	[Enum.KeyCode.LessThan] = "Keyboard",
	[Enum.KeyCode.GreaterThan] = "Keyboard",
	[Enum.KeyCode.Question] = "Keyboard",
	[Enum.KeyCode.At] = "Keyboard",

	-- Function Keys
	[Enum.KeyCode.F1] = "Keyboard",
	[Enum.KeyCode.F2] = "Keyboard",
	[Enum.KeyCode.F3] = "Keyboard",
	[Enum.KeyCode.F4] = "Keyboard",
	[Enum.KeyCode.F5] = "Keyboard",
	[Enum.KeyCode.F6] = "Keyboard",
	[Enum.KeyCode.F7] = "Keyboard",
	[Enum.KeyCode.F8] = "Keyboard",
	[Enum.KeyCode.F9] = "Keyboard",
	[Enum.KeyCode.F10] = "Keyboard",
	[Enum.KeyCode.F11] = "Keyboard",
	[Enum.KeyCode.F12] = "Keyboard",
	[Enum.KeyCode.F13] = "Keyboard",
	[Enum.KeyCode.F14] = "Keyboard",
	[Enum.KeyCode.F15] = "Keyboard",

	-- Gamepad Buttons
	[Enum.KeyCode.ButtonA] = "Gamepad",
	[Enum.KeyCode.ButtonB] = "Gamepad",
	[Enum.KeyCode.ButtonX] = "Gamepad",
	[Enum.KeyCode.ButtonY] = "Gamepad",
	[Enum.KeyCode.ButtonL1] = "Gamepad",
	[Enum.KeyCode.ButtonR1] = "Gamepad",
	[Enum.KeyCode.ButtonL2] = "Gamepad",
	[Enum.KeyCode.ButtonR2] = "Gamepad",
	[Enum.KeyCode.ButtonL3] = "Gamepad",
	[Enum.KeyCode.ButtonR3] = "Gamepad",
	[Enum.KeyCode.DPadUp] = "Gamepad",
	[Enum.KeyCode.DPadDown] = "Gamepad",
	[Enum.KeyCode.DPadLeft] = "Gamepad",
	[Enum.KeyCode.DPadRight] = "Gamepad",
	[Enum.KeyCode.ButtonStart] = "Gamepad",
	[Enum.KeyCode.ButtonSelect] = "Gamepad",

	-- MicroGamepad / TV Remote
	[Enum.KeyCode.ButtonCenter] = "Gamepad",
	[Enum.KeyCode.ButtonBack] = "Gamepad",
	[Enum.KeyCode.ButtonUp] = "Gamepad",
	[Enum.KeyCode.ButtonDown] = "Gamepad",
	[Enum.KeyCode.ButtonLeft] = "Gamepad",
	[Enum.KeyCode.ButtonRight] = "Gamepad",

	-- Gamepad Thumbsticks & Directional Vectors (IAS KeyCodes)
	[Enum.KeyCode.Thumbstick1] = "Gamepad",
	[Enum.KeyCode.Thumbstick2] = "Gamepad",
	[Enum.KeyCode.Thumbstick1Up] = "Gamepad",
	[Enum.KeyCode.Thumbstick1Down] = "Gamepad",
	[Enum.KeyCode.Thumbstick1Left] = "Gamepad",
	[Enum.KeyCode.Thumbstick1Right] = "Gamepad",
	[Enum.KeyCode.Thumbstick2Up] = "Gamepad",
	[Enum.KeyCode.Thumbstick2Down] = "Gamepad",
	[Enum.KeyCode.Thumbstick2Left] = "Gamepad",
	[Enum.KeyCode.Thumbstick2Right] = "Gamepad",

	-- Touch (IAS KeyCodes)
	[Enum.KeyCode.TouchPosition] = "Mobile",
	[Enum.KeyCode.TouchDelta] = "Mobile",
	[Enum.KeyCode.TouchPinch] = "Mobile",
}

return {
	InputTypeByKey = InputTypeByKey
}
