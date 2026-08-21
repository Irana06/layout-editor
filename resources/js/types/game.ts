export type Scenery = {
    id: number;
    name: string;
    file_path: string;
    image_width: number;
    image_height: number;
    tile_w: number;
    tile_h: number;
    origin_x: number;
    origin_y: number;
    grid_n: number;
    calibrated: boolean;
    locked: boolean;
};

export type BuildingLevel = {
    id: number;
    building_type_id: number;
    level: number;
    file_path: string;
    grid_width: number | null;
    grid_height: number | null;
    scale: number;
    offset_x: number;
    offset_y: number;
};

export type BuildingType = {
    id: number;
    name: string;
    category: string;
    subfolder: string | null;
    is_town_hall: boolean;
    default_grid_width: number;
    default_grid_height: number;
    levels: BuildingLevel[];
};

export type BuildingUnlockRule = {
    id: number;
    building_type_id: number;
    th_level: number;
    max_building_level: number;
};

export type LayoutPlacement = { building_type_id: number; level: number; gx: number; gy: number };

export type ServerLayout = {
    id: string;
    title: string;
    th_level: number;
    scenery_id: number;
    data: LayoutPlacement[];
    thumbnail_data: string | null;
    share_enabled: boolean;
    share_slug: string | null;
    created_at: string;
    updated_at: string;
};

export function levelFootprint(type: BuildingType, level: BuildingLevel): { width: number; height: number } {
    return {
        width: level.grid_width ?? type.default_grid_width,
        height: level.grid_height ?? type.default_grid_height,
    };
}
