# Stoway - Project Context

## Project Overview
**Stoway** (V2.4.0) is a robust, data-driven inventory and hotbar system designed for Roblox experiences. It features a reactive UI powered by Fusion, efficient delta replication, and a modular architecture supporting various gameplay styles (RPG, survival, etc.).

### Key Technologies
*   **Language:** Luau
*   **Frameworks/Libraries:**
    *   **Fusion:** For reactive UI development.
    *   **Janitor:** For memory management and cleanup.
    *   **IllusionIAS:** (Inferred from folder structure) For input handling.
*   **Tools:**
    *   **Rojo:** For synchronizing the filesystem with Roblox Studio (managed via `aftman.toml`).
    *   **Wally:** For package management (dependencies defined in `wally.toml`).
    *   **Aftman:** For toolchain management.

## Architecture
The project follows a standard Roblox service-oriented architecture, split between Client, Server, and Shared resources.

### Directory Structure
*   **`src/client`**: Contains the client-side logic.
    *   `init.client.luau`: Entry point.
    *   `StowayClientv1_2`: Main client module containing sub-modules for Input, UI, Networking, etc.
*   **`src/server`**: Contains the server-side logic.
    *   `init.server.luau`: Entry point.
    *   `StowayServerV1_2`: Main server module containing sub-modules for Core logic, Operations (Add, Drop, Equip), Replication, etc.
*   **`src/shared`**: Shared resources available to both client and server.
    *   `Settings.luau`: Central configuration file.
    *   `Types.luau`: Shared type definitions.
    *   `RarityValues.luau` & `Binds.luau`: Additional data modules.
*   **`Packages`**: External dependencies installed via Wally.

### Data Flow
1.  **Server Authority:** The server maintains the true state of the inventory (Items, Amounts, Stats).
2.  **Delta Replication:** Changes are sent to clients via a `Replicator` module, ensuring minimal bandwidth usage.
3.  **Client Prediction/Reaction:** The client uses `Fusion` to reactively update the UI based on the replicated state.
4.  **Input:** User actions (Keybinds, Drag & Drop) are handled by the Client and validated/executed by the Server via Operations.

## Configuration
The system is highly configurable via `src/shared/Settings.luau`.
*   **Hotbar:** Define slot count and type (Static vs Dynamic).
*   **Storage:** Set weight limits, stack sizes, and sorting rules.
*   **Gameplay:** Toggle mechanics like item dropping and scrolling.
*   **UI Skins:** Configure different UI themes (e.g., Default, Admin).

## Development Workflow

### Building & Syncing
This project uses **Rojo** to sync files to Roblox Studio.
*   **Project File:** `default.project.json` defines the mapping between the filesystem and Roblox services (`ReplicatedStorage`, `ServerScriptService`, `StarterPlayerScripts`).
*   **Sync:** Run `rojo serve` to start the sync server.

### Dependency Management
*   **Install:** Run `wally install` to fetch dependencies defined in `wally.toml`.
*   **Output:** Dependencies are installed into the `Packages` directory.

### Conventions
*   **Code Style:** Luau with type checking (`export type ...`).
*   **Naming:** PascalCase for services and modules.
*   **State Management:** Fusion `Value` and `Observer` patterns for UI state.
