export type Placement = {
    uid: string;
    buildingTypeId: number;
    level: number;
    gx: number;
    gy: number;
};

export type Tool = 'select' | 'place';

export type SelectionBox = { start: { gx: number; gy: number }; end: { gx: number; gy: number } } | null;

export type EditorState = {
    sceneryId: number | null;
    thLevel: number;
    placements: Placement[];
    selectedIds: string[];
    selectionBox: SelectionBox;
    tool: Tool;
    armed: { buildingTypeId: number; level: number } | null;
    lastPickedLevel: Record<number, number>;
    showGrid: boolean;
    showFootprint: boolean;
    history: Placement[][];
    historyIndex: number;
    layoutId: string | null;
    layoutTitle: string;
    shareEnabled: boolean;
    shareSlug: string | null;
    status: string;
    readOnly: boolean;
};

export type EditorAction =
    | { type: 'SET_SCENERY'; sceneryId: number }
    | { type: 'SET_TH_LEVEL'; thLevel: number }
    | { type: 'ARM'; buildingTypeId: number; level: number }
    | { type: 'DISARM' }
    | { type: 'SET_TOOL'; tool: Tool }
    | { type: 'COMMIT_PLACEMENTS'; placements: Placement[] }
    | { type: 'SELECT'; ids: string[] }
    | { type: 'SET_SELECTION_BOX'; box: SelectionBox }
    | { type: 'TOGGLE_GRID' }
    | { type: 'TOGGLE_FOOTPRINT' }
    | { type: 'UNDO' }
    | { type: 'REDO' }
    | { type: 'SET_LAST_PICKED_LEVEL'; buildingTypeId: number; level: number }
    | {
          type: 'LOAD_LAYOUT';
          layoutId: string | null;
          layoutTitle: string;
          thLevel: number;
          sceneryId: number | null;
          placements: Placement[];
          shareEnabled: boolean;
          shareSlug: string | null;
      }
    | { type: 'RESET' }
    | { type: 'SET_TITLE'; title: string }
    | { type: 'SET_STATUS'; status: string }
    | { type: 'SET_SHARE'; shareEnabled: boolean; shareSlug: string | null }
    | { type: 'SET_LAYOUT_ID'; layoutId: string };

function pushHistory(state: EditorState, placements: Placement[]): Pick<EditorState, 'placements' | 'history' | 'historyIndex'> {
    const nextHistory = [...state.history.slice(0, state.historyIndex + 1), placements];

    return { placements, history: nextHistory, historyIndex: nextHistory.length - 1 };
}

export function editorReducer(state: EditorState, action: EditorAction): EditorState {
    switch (action.type) {
        case 'SET_SCENERY':
            return { ...state, sceneryId: action.sceneryId };
        case 'SET_TH_LEVEL':
            return { ...state, thLevel: action.thLevel };
        case 'ARM':
            return { ...state, armed: { buildingTypeId: action.buildingTypeId, level: action.level }, tool: 'place', selectedIds: [] };
        case 'DISARM':
            return { ...state, armed: null, tool: state.tool === 'place' ? 'select' : state.tool };
        case 'SET_TOOL':
            return { ...state, tool: action.tool, armed: action.tool === 'place' ? state.armed : null };
        case 'COMMIT_PLACEMENTS':
            return { ...state, ...pushHistory(state, action.placements) };
        case 'SELECT':
            return { ...state, selectedIds: action.ids };
        case 'SET_SELECTION_BOX':
            return { ...state, selectionBox: action.box };
        case 'TOGGLE_GRID':
            return { ...state, showGrid: !state.showGrid };
        case 'TOGGLE_FOOTPRINT':
            return { ...state, showFootprint: !state.showFootprint };
        case 'UNDO': {
            if (state.historyIndex <= 0) {
return state;
}

            const historyIndex = state.historyIndex - 1;

            return { ...state, historyIndex, placements: state.history[historyIndex] };
        }
        case 'REDO': {
            if (state.historyIndex >= state.history.length - 1) {
return state;
}

            const historyIndex = state.historyIndex + 1;

            return { ...state, historyIndex, placements: state.history[historyIndex] };
        }
        case 'SET_LAST_PICKED_LEVEL':
            return { ...state, lastPickedLevel: { ...state.lastPickedLevel, [action.buildingTypeId]: action.level } };
        case 'LOAD_LAYOUT':
            return {
                ...state,
                layoutId: action.layoutId,
                layoutTitle: action.layoutTitle,
                thLevel: action.thLevel,
                sceneryId: action.sceneryId,
                placements: action.placements,
                history: [action.placements],
                historyIndex: 0,
                shareEnabled: action.shareEnabled,
                shareSlug: action.shareSlug,
                selectedIds: [],
            };
        case 'RESET':
            return { ...state, ...pushHistory(state, []), selectedIds: [] };
        case 'SET_TITLE':
            return { ...state, layoutTitle: action.title };
        case 'SET_STATUS':
            return { ...state, status: action.status };
        case 'SET_SHARE':
            return { ...state, shareEnabled: action.shareEnabled, shareSlug: action.shareSlug };
        case 'SET_LAYOUT_ID':
            return { ...state, layoutId: action.layoutId };
        default:
            return state;
    }
}

export function initialEditorState(overrides: Partial<EditorState> = {}): EditorState {
    return {
        sceneryId: null,
        thLevel: 1,
        placements: [],
        selectedIds: [],
        selectionBox: null,
        tool: 'select',
        armed: null,
        lastPickedLevel: {},
        showGrid: true,
        showFootprint: true,
        history: [[]],
        historyIndex: 0,
        layoutId: null,
        layoutTitle: 'Layout tanpa judul',
        shareEnabled: false,
        shareSlug: null,
        status: 'Pilih bangunan untuk mulai membangun.',
        readOnly: false,
        ...overrides,
    };
}
