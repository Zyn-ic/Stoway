# Error Codes

Every mutation returns a `Result`: `{ ok = true, value = … }` or
`{ ok = false, error = { kind, message } }`. `message` is the reason string;
`kind` tells you the class.

| Kind | Reasons |
|---|---|
| `PermissionDenied` | `BACKPACK_DISABLED`, `NOT_DROPPABLE` |
| `InvalidArgument` | `INVALID_HOTBAR_SLOT`, `INVALID_STORAGE_SLOT`, `INVALID_AMOUNT`, `INVALID_ITEM_DATA`, `INVALID_SLOT`, `INVALID_PLACEMENT`, `INVALID_ITEM_ID`, `INVALID_OPERATION`, `CANNOT_SPLIT_FULL`, `ITEM_NOT_IN_TOOLS_FOLDER` |
| `NotFound` | `ITEM_NOT_FOUND`, `NO_STATE`, `SOURCE_EMPTY`, `SLOT_EMPTY` |
| `NotAvailable` | `FULL`, `HOTBAR_FULL`, `HOTBAR_SLOT_OCCUPIED`, `DESTINATION_OCCUPIED`, `DESTINATION_UNAVAILABLE`, `NO_SPACE`, `ADD_FAILED`, `OPERATION_IN_PROGRESS` |
