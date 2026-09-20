--@author: yyumchi
--@date: 2026-08-17
--[[@description:
	Rust-style Result type for Stoway.
	Provides Result<T, E>, ErrorKind enum table, Error type, Ok() and Err() constructors.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Result = {}

-----------------------------
-- CONSTANTS --
-----------------------------

export type ErrorKind = "PermissionDenied" | "InvalidArgument" | "NotFound" | "NotAvailable"

local ERROR_KIND: {
	PermissionDenied: "PermissionDenied",
	InvalidArgument: "InvalidArgument",
	NotFound: "NotFound",
	NotAvailable: "NotAvailable",
} = {
	PermissionDenied = "PermissionDenied",
	InvalidArgument = "InvalidArgument",
	NotFound = "NotFound",
	NotAvailable = "NotAvailable",
}

Result.ErrorKind = ERROR_KIND

export type Error = {
	kind: ErrorKind,
	message: string,
}

export type Ok<T> = { ok: true, value: T }
export type Err<E = Error> = { ok: false, error: E }

export type Result<T, E = Error> =
	| Ok<T>
	| Err<E>

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Result.Ok<T>(value: T): Ok<T>
	return { ok = true, value = value }
end

function Result.Err(error: Error): Err<Error>
	return { ok = false, error = error }
end

-----------------------------
--MAIN--
-----------------------------

return Result
