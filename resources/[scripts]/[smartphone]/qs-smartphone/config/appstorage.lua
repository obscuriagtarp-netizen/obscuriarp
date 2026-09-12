--──────────────────────────────────────────────────────────────────────────────
-- App Storage                                                                 [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.AppStorage = {
    enabled = true,
    defaultCapacityMb = 8192, -- 8 GB base capacity per phone
    allowUninstallToFreeSpace = true,
    fallbackSystemAppSizeMb = 85,

    -- Gallery media (photo/video) also consumes the same total phone storage.
    media = {
        enabled = true,
        estimatedPhotoMb = 4,  -- Average compressed mobile photo
        estimatedVideoMb = 32, -- Short mobile clip default estimate
    },
}
