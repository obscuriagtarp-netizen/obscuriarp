-- Execute uma vez, com o servidor parado, para preservar itens existentes.
-- A migracao e idempotente: repetir o arquivo nao altera os IDs ja convertidos.

START TRANSACTION;

UPDATE `players`
SET `inventory` =
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        `inventory`,
        'ob_amuleto_latente', 'amuleto_latente'),
        'ob_colar_latente', 'colar_latente'),
        'ob_cinto_latente', 'cinto_latente'),
        'ob_anel_latente', 'anel_latente'),
        'ob_frasco_vazio', 'frasco_vazio'),
        'ob_sangue_puma', 'sangue_puma'),
        'ob_carne_puma', 'carne_puma'),
        'ob_couro_puma', 'couro_puma'),
        'ob_amuleto_eclipse', 'amuleto_eclipse'),
        'ob_batata_frita', 'batata_frita'),
        'ob_refrigerante', 'refrigerante'),
        'ob_hamburguer', 'hamburguer'),
        'ob_combo_box', 'combo_box'),
        'ob_refresco', 'refrigerante'),
        'ob_salad', 'salad'),
        'ob_batata', 'batata'),
        'ob_xarope', 'xarope'),
        'ob_carne', 'carne'),
        'ob_pao', 'pao')
WHERE `inventory` LIKE '%ob_%';

UPDATE `ox_inventory`
SET `data` =
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        `data`,
        'ob_amuleto_latente', 'amuleto_latente'),
        'ob_colar_latente', 'colar_latente'),
        'ob_cinto_latente', 'cinto_latente'),
        'ob_anel_latente', 'anel_latente'),
        'ob_frasco_vazio', 'frasco_vazio'),
        'ob_sangue_puma', 'sangue_puma'),
        'ob_carne_puma', 'carne_puma'),
        'ob_couro_puma', 'couro_puma'),
        'ob_amuleto_eclipse', 'amuleto_eclipse'),
        'ob_batata_frita', 'batata_frita'),
        'ob_refrigerante', 'refrigerante'),
        'ob_hamburguer', 'hamburguer'),
        'ob_combo_box', 'combo_box'),
        'ob_refresco', 'refrigerante'),
        'ob_salad', 'salad'),
        'ob_batata', 'batata'),
        'ob_xarope', 'xarope'),
        'ob_carne', 'carne'),
        'ob_pao', 'pao')
WHERE `data` LIKE '%ob_%';

UPDATE `player_vehicles`
SET `trunk` =
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        `trunk`,
        'ob_amuleto_latente', 'amuleto_latente'),
        'ob_colar_latente', 'colar_latente'),
        'ob_cinto_latente', 'cinto_latente'),
        'ob_anel_latente', 'anel_latente'),
        'ob_frasco_vazio', 'frasco_vazio'),
        'ob_sangue_puma', 'sangue_puma'),
        'ob_carne_puma', 'carne_puma'),
        'ob_couro_puma', 'couro_puma'),
        'ob_amuleto_eclipse', 'amuleto_eclipse'),
        'ob_batata_frita', 'batata_frita'),
        'ob_refrigerante', 'refrigerante'),
        'ob_hamburguer', 'hamburguer'),
        'ob_combo_box', 'combo_box'),
        'ob_refresco', 'refrigerante'),
        'ob_salad', 'salad'),
        'ob_batata', 'batata'),
        'ob_xarope', 'xarope'),
        'ob_carne', 'carne'),
        'ob_pao', 'pao'),
    `glovebox` =
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        `glovebox`,
        'ob_amuleto_latente', 'amuleto_latente'),
        'ob_colar_latente', 'colar_latente'),
        'ob_cinto_latente', 'cinto_latente'),
        'ob_anel_latente', 'anel_latente'),
        'ob_frasco_vazio', 'frasco_vazio'),
        'ob_sangue_puma', 'sangue_puma'),
        'ob_carne_puma', 'carne_puma'),
        'ob_couro_puma', 'couro_puma'),
        'ob_amuleto_eclipse', 'amuleto_eclipse'),
        'ob_batata_frita', 'batata_frita'),
        'ob_refrigerante', 'refrigerante'),
        'ob_hamburguer', 'hamburguer'),
        'ob_combo_box', 'combo_box'),
        'ob_refresco', 'refrigerante'),
        'ob_salad', 'salad'),
        'ob_batata', 'batata'),
        'ob_xarope', 'xarope'),
        'ob_carne', 'carne'),
        'ob_pao', 'pao')
WHERE `trunk` LIKE '%ob_%' OR `glovebox` LIKE '%ob_%';

COMMIT;
