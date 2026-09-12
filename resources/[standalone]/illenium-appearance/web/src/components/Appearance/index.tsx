import { useState, useEffect, useCallback, useMemo } from 'react';
import { useTransition as useTransitionAnimation, animated } from 'react-spring';
import { useNuiState } from '../../hooks/nuiState';
import Nui from '../../Nui';
import mock from '../../mock';

import {
  CustomizationConfig,
  PedAppearance,
  AppearanceSettings,
  PedHeadBlend,
  PedFaceFeatures,
  PedHeadOverlays,
  PedHeadOverlayValue,
  PedHair,
  CameraState,
  ClothesState,
  Tattoo,
  TattoosSettings,
} from './interfaces';

import {
  APPEARANCE_INITIAL_STATE,
  SETTINGS_INITIAL_STATE,
  CAMERA_INITIAL_STATE,
  ROTATE_INITIAL_STATE,
  CLOTHES_INITIAL_STATE,
} from './settings';

import Ped from './Ped';
import HeadBlend from './HeadBlend';
import FaceFeatures from './FaceFeatures';
import HeadOverlays from './HeadOverlays';
import Components from './Components';
import Props from './Props';
import Options from './Options';
import Modal from '../Modal';
import Tattoos from './Tattoos';
import { FaDna, FaHatCowboy, FaMagic, FaPaintBrush, FaSmile, FaTshirt, FaUser } from 'react-icons/fa';

import { Body, Container, Content, Navigation, NavButton, PanelHeader, Wrapper } from './styles';

const isBrowserPreview = typeof (window as any).GetParentResourceName !== 'function';
if (isBrowserPreview) document.body.classList.add('browser-preview');

const PREVIEW_LOCALES: any = {
  modal: {
    save: { title: 'Confirmar aparência', description: 'Deseja salvar as alterações realizadas?' },
    exit: { title: 'Descartar alterações', description: 'Deseja sair sem salvar sua aparência?' },
    accept: 'Confirmar', decline: 'Voltar',
  },
  ped: { title: 'Identidade', model: 'Modelo do personagem' },
  headBlend: {
    title: 'Herança',
    shape: { title: 'Traços', firstOption: 'Ascendência principal', secondOption: 'Ascendência secundária', mix: 'Mistura dos traços' },
    skin: { title: 'Pele', firstOption: 'Tom principal', secondOption: 'Tom secundário', mix: 'Mistura da pele' },
    race: { title: 'Terceira herança', shape: 'Traços', skin: 'Pele', mix: 'Influência' },
  },
  faceFeatures: {
    title: 'Estrutura facial',
    nose: { title: 'Nariz', width: 'Largura', height: 'Altura', size: 'Tamanho', boneHeight: 'Ponte', boneTwist: 'Inclinação', peakHeight: 'Ponta' },
    eyebrows: { title: 'Sobrancelhas', height: 'Altura', depth: 'Profundidade' },
    cheeks: { title: 'Maçãs do rosto', boneHeight: 'Altura', boneWidth: 'Largura óssea', width: 'Largura' },
    eyesAndMouth: { title: 'Olhos e boca', eyesOpening: 'Abertura dos olhos', lipsThickness: 'Espessura dos lábios' },
    jaw: { title: 'Mandíbula', width: 'Largura', size: 'Tamanho' },
    chin: { title: 'Queixo', lowering: 'Altura', length: 'Comprimento', size: 'Tamanho', hole: 'Fenda' },
    neck: { title: 'Pescoço', thickness: 'Espessura' },
  },
  headOverlays: {
    title: 'Detalhes e cabelo',
    hair: { title: 'Cabelo', style: 'Corte', color: 'Cor', highlight: 'Reflexo', fade: 'Degradê', texture: 'Textura' },
    opacity: 'Intensidade', style: 'Estilo', color: 'Cor', secondColor: 'Cor secundária',
    blemishes: 'Marcas', beard: 'Barba', eyebrows: 'Sobrancelhas', ageing: 'Envelhecimento', makeUp: 'Maquiagem', blush: 'Blush', complexion: 'Pele', sunDamage: 'Danos solares', lipstick: 'Batom', moleAndFreckles: 'Sardas e pintas', chestHair: 'Pelos corporais', bodyBlemishes: 'Marcas corporais', eyeColor: 'Cor dos olhos',
  },
  components: { title: 'Vestuário', drawable: 'Modelo', texture: 'Variação', mask: 'Máscara', upperBody: 'Braços', lowerBody: 'Calças', bags: 'Bolsas', shoes: 'Calçados', scarfAndChains: 'Colares', shirt: 'Camisa', bodyArmor: 'Colete', decals: 'Estampas', jackets: 'Jaqueta', head: 'Cabeça' },
  props: { title: 'Acessórios', drawable: 'Modelo', texture: 'Variação', hats: 'Chapéus', glasses: 'Óculos', ear: 'Brincos', watches: 'Relógios', bracelets: 'Pulseiras' },
  tattoos: { title: 'Tatuagens', items: { ZONE_HEAD: 'Cabeça', ZONE_TORSO: 'Torso', ZONE_LEFT_ARM: 'Braço esquerdo', ZONE_RIGHT_ARM: 'Braço direito', ZONE_LEFT_LEG: 'Perna esquerda', ZONE_RIGHT_LEG: 'Perna direita' }, apply: 'Aplicar', delete: 'Remover', deleteAll: 'Remover todas', opacity: 'Intensidade' },
};

const PREVIEW_TATTOOS: any = {
  ZONE_TORSO: [
    { name: 'PREVIEW_TORSO_1', label: 'Turbulência', hashMale: 'MP_Airraces_Tattoo_000_M', hashFemale: 'MP_Airraces_Tattoo_000_F', zone: 'ZONE_TORSO', collection: 'mpairraces_overlays' },
    { name: 'PREVIEW_TORSO_2', label: 'Caveira náutica', hashMale: 'MP_Bea_M_Chest_000', hashFemale: 'MP_Bea_F_Chest_000', zone: 'ZONE_TORSO', collection: 'mpbeach_overlays' },
    { name: 'PREVIEW_TORSO_3', label: 'Maré antiga', hashMale: 'MP_Bea_M_Back_001', hashFemale: 'MP_Bea_F_Back_001', zone: 'ZONE_TORSO', collection: 'mpbeach_overlays' },
  ],
  ZONE_HEAD: [
    { name: 'PREVIEW_HEAD_1', label: 'Marca do pescoço', hashMale: 'MP_Bea_M_Neck_000', hashFemale: 'MP_Bea_F_Neck_000', zone: 'ZONE_HEAD', collection: 'mpbeach_overlays' },
    { name: 'PREVIEW_HEAD_2', label: 'Insígnia executiva', hashMale: 'MP_Buis_M_Neck_000', hashFemale: 'MP_Buis_F_Neck_000', zone: 'ZONE_HEAD', collection: 'mpbusiness_overlays' },
  ],
  ZONE_LEFT_ARM: [
    { name: 'PREVIEW_LARM_1', label: 'Braço costeiro', hashMale: 'MP_Bea_M_LArm_000', hashFemale: 'MP_Bea_F_LArm_000', zone: 'ZONE_LEFT_ARM', collection: 'mpbeach_overlays' },
    { name: 'PREVIEW_LARM_2', label: 'Marca dos negócios', hashMale: 'MP_Buis_M_LArm_000', hashFemale: 'MP_Buis_F_LArm_000', zone: 'ZONE_LEFT_ARM', collection: 'mpbusiness_overlays' },
  ],
  ZONE_RIGHT_ARM: [
    { name: 'PREVIEW_RARM_1', label: 'Traço marítimo', hashMale: 'MP_Bea_M_RArm_001', hashFemale: 'MP_Bea_F_RArm_001', zone: 'ZONE_RIGHT_ARM', collection: 'mpbeach_overlays' },
    { name: 'PREVIEW_RARM_2', label: 'Marca corporativa', hashMale: 'MP_Buis_M_RArm_000', hashFemale: 'MP_Buis_F_RArm_000', zone: 'ZONE_RIGHT_ARM', collection: 'mpbusiness_overlays' },
  ],
  ZONE_LEFT_LEG: [
    { name: 'PREVIEW_LLEG_1', label: 'Selo da perna', hashMale: 'MP_Buis_M_LLeg_000', hashFemale: 'MP_Buis_F_LLeg_000', zone: 'ZONE_LEFT_LEG', collection: 'mpbusiness_overlays' },
  ],
  ZONE_RIGHT_LEG: [
    { name: 'PREVIEW_RLEG_1', label: 'Linha costeira', hashMale: 'MP_Bea_M_RLeg_000', hashFemale: 'MP_Bea_F_RLeg_000', zone: 'ZONE_RIGHT_LEG', collection: 'mpbeach_overlays' },
    { name: 'PREVIEW_RLEG_2', label: 'Emblema da perna', hashMale: 'MP_Buis_M_RLeg_000', hashFemale: 'MP_Buis_F_RLeg_000', zone: 'ZONE_RIGHT_LEG', collection: 'mpbusiness_overlays' },
  ],
};

if (!import.meta.env.PROD || isBrowserPreview) {
  mock('appearance_get_settings', () => ({
    appearanceSettings: {
      ...SETTINGS_INITIAL_STATE,
      eyeColor: { min: 0, max: 24 },
      hair: {
        ...SETTINGS_INITIAL_STATE.hair,
        color: {
          items: [
            [255, 0, 0],
            [0, 255, 0],
            [0, 0, 255],
            [0, 0, 255],
          ],
        },
      },
      tattoos: { ...SETTINGS_INITIAL_STATE.tattoos, items: PREVIEW_TATTOOS },
    },
  }));

  mock('appearance_get_locales', () => PREVIEW_LOCALES);

  mock('appearance_get_data', () => ({
    config: {
      uiEyebrow: 'Primeiros passos',
      uiTitle: 'Criação de Personagem',
      uiDescription: 'Defina os traços, o vestuário e os detalhes do seu personagem.',
      ped: true, headBlend: true, faceFeatures: true, headOverlays: true, components: true, props: true, tattoos: true,
      enableExit: true, hasTracker: false, automaticFade: false,
      componentConfig: { masks: true, upperBody: true, lowerBody: true, bags: true, shoes: true, scarfAndChains: true, shirts: true, bodyArmor: true, decals: true, jackets: true },
      propConfig: { hats: true, glasses: true, ear: true, watches: true, bracelets: true },
    },
    appearanceData: { ...APPEARANCE_INITIAL_STATE, model: 'mp_f_freemode_01' },
  }));

  mock('appearance_change_model', () => ({
    appearanceSettings: { ...SETTINGS_INITIAL_STATE, tattoos: { ...SETTINGS_INITIAL_STATE.tattoos, items: PREVIEW_TATTOOS } },
    appearanceData: APPEARANCE_INITIAL_STATE,
  }));

  mock('appearance_change_component', (value: any) => SETTINGS_INITIAL_STATE.components.find(item => item.component_id === value.component_id));

  mock('appearance_change_prop', (value: any) => SETTINGS_INITIAL_STATE.props.find(item => item.prop_id === value.prop_id));
  mock('appearance_change_hair', () => SETTINGS_INITIAL_STATE.hair);
  ['appearance_set_camera', 'appearance_turn_around', 'appearance_rotate_camera', 'appearance_change_head_blend', 'appearance_change_face_feature', 'appearance_change_head_overlay', 'appearance_change_eye_color', 'appearance_apply_tattoo', 'appearance_preview_tattoo', 'appearance_delete_tattoo', 'appearance_wear_clothes', 'appearance_remove_clothes', 'appearance_save', 'appearance_exit', 'rotate_left', 'rotate_right'].forEach(event => mock(event, () => 1));
}

const Appearance = () => {
  const [config, setConfig] = useState<CustomizationConfig>();

  const [data, setData] = useState<PedAppearance>();
  const [storedData, setStoredData] = useState<PedAppearance>();
  const [appearanceSettings, setAppearanceSettings] = useState<AppearanceSettings>();

  const [camera, setCamera] = useState(CAMERA_INITIAL_STATE);
  const [rotate, setRotate] = useState(ROTATE_INITIAL_STATE);
  const [clothes, setClothes] = useState(CLOTHES_INITIAL_STATE);

  const [saveModal, setSaveModal] = useState(false);
  const [exitModal, setExitModal] = useState(false);
  const [activeTab, setActiveTab] = useState('identity');

  const { display, setDisplay, locales, setLocales } = useNuiState();

  const wrapperTransition = useTransitionAnimation(display.appearance, null, {
    from: { transform: 'translateX(-50px)', opacity: 0 },
    enter: { transform: 'translateY(0)', opacity: 1 },
    leave: { transform: 'translateX(-50px)', opacity: 0 },
  });

  const saveModalTransition = useTransitionAnimation(saveModal, null, {
    from: { opacity: 0 },
    enter: { opacity: 1 },
    leave: { opacity: 0 },
  });

  const exitModalTransition = useTransitionAnimation(exitModal, null, {
    from: { opacity: 0 },
    enter: { opacity: 1 },
    leave: { opacity: 0 },
  });

  const handleTurnAround = useCallback(() => {
    Nui.post('appearance_turn_around');
  }, []);

  const handleSetClothes = useCallback(
    (key: keyof ClothesState) => {
      setClothes({ ...clothes, [key]: !clothes[key] });
      if (!clothes[key]) {
        Nui.post('appearance_remove_clothes', key);
      } else {
        Nui.post('appearance_wear_clothes', { data, key });
      }
    },
    [data, clothes, setClothes],
  );

  const handleSetCamera = useCallback(
    (key: keyof CameraState) => {
      setCamera({ ...CAMERA_INITIAL_STATE, [key]: !camera[key] });
      setRotate(ROTATE_INITIAL_STATE);

      if (!camera[key]) {
        Nui.post('appearance_set_camera', key);
      } else {
        Nui.post('appearance_set_camera', 'default');
      }
    },
    [camera, setCamera, setRotate],
  );

  const handleRotateLeft = useCallback(() => {
    setRotate({ left: !rotate.left, right: false });

    if (!rotate.left) {
      Nui.post('appearance_rotate_camera', 'left');
    } else {
      Nui.post('appearance_set_camera', 'current');
    }
  }, [setRotate, rotate]);

  const handleRotateRight = useCallback(() => {
    setRotate({ left: false, right: !rotate.right });

    if (!rotate.right) {
      Nui.post('appearance_rotate_camera', 'right');
    } else {
      Nui.post('appearance_set_camera', 'current');
    }
  }, [setRotate, rotate]);

  const handleSaveModal = useCallback(() => {
    setSaveModal(true);
  }, [setSaveModal]);

  const handleExitModal = useCallback(() => {
    setExitModal(true);
  }, [setExitModal]);

  const handleSave = useCallback(
    async (accept: boolean) => {
      if (accept) {
        await Nui.post('appearance_save', data);
        setSaveModal(false);
      } else {
        setSaveModal(false);
      }
    },
    [setSaveModal, data],
  );

  const handleExit = useCallback(
    async (accept: boolean) => {
      if (accept) {
        await Nui.post('appearance_exit');
        setExitModal(false);
      } else {
        setExitModal(false);
      }
    },
    [setExitModal],
  );

  const handleModelChange = useCallback(
    async (value: string) => {
      const { appearanceSettings: _appearanceSettings, appearanceData } = await Nui.post(
        'appearance_change_model',
        value,
      );

      setAppearanceSettings(_appearanceSettings);
      setData(appearanceData);
    },
    [setData, setAppearanceSettings],
  );

  const handleHeadBlendChange = useCallback(
    (key: keyof PedHeadBlend, value: number) => {
      if (!data) return;

      const updatedHeadBlend = { ...data.headBlend, [key]: value };

      const updatedData = { ...data, headBlend: updatedHeadBlend };

      setData(updatedData);

      Nui.post('appearance_change_head_blend', updatedHeadBlend);
    },
    [data, setData],
  );

  const handleFaceFeatureChange = useCallback(
    (key: keyof PedFaceFeatures, value: number) => {
      if (!data) return;

      const updatedFaceFeatures = { ...data.faceFeatures, [key]: value };

      const updatedData = { ...data, faceFeatures: updatedFaceFeatures };

      setData(updatedData);

      Nui.post('appearance_change_face_feature', updatedFaceFeatures);
    },
    [data, setData],
  );

  const handleHairChange = useCallback(
    async (key: keyof PedHair, value: number) => {
      if (!data || !appearanceSettings) return;

      const updatedHair = { ...data.hair, [key]: value };

      const updatedData = { ...data, hair: updatedHair };

      setData(updatedData);

      const updatedHairSettings = await Nui.post('appearance_change_hair', updatedHair);

      const updatedSettings = { ...appearanceSettings, hair: updatedHairSettings };

      setAppearanceSettings(updatedSettings);
    },
    [data, setData, appearanceSettings, setAppearanceSettings],
  );

  const handleChangeFade = useCallback(async (value: number) => {
    if (!data || !appearanceSettings) return;
      const { tattoos } = data;
      const updatedTattoos = { ...tattoos };
      const tattoo = appearanceSettings.tattoos.items['ZONE_HAIR'][value]
      if (!updatedTattoos[tattoo.zone]) updatedTattoos[tattoo.zone] = [];
      updatedTattoos[tattoo.zone] = [tattoo];
      await Nui.post('appearance_apply_tattoo', updatedTattoos);
      setData({ ...data, tattoos: updatedTattoos });
  }, [appearanceSettings, data, setData])

  const handleHeadOverlayChange = useCallback(
    (key: keyof PedHeadOverlays, option: keyof PedHeadOverlayValue, value: number) => {
      if (!data) return;

      const updatedValue = { ...data.headOverlays[key], [option]: value };

      const updatedData = { ...data, headOverlays: { ...data.headOverlays, [key]: updatedValue } };

      setData(updatedData);

      Nui.post('appearance_change_head_overlay', { ...data.headOverlays, [key]: updatedValue });
    },
    [data, setData],
  );

  const handleEyeColorChange = useCallback(
    (value: number) => {
      if (!data) return;

      const updatedData = { ...data, eyeColor: value };

      setData(updatedData);

      Nui.post('appearance_change_eye_color', value);
    },
    [data, setData],
  );

  const handleComponentDrawableChange = useCallback(
    async (component_id: number, drawable: number) => {
      if (!data || !appearanceSettings) return;

      const component = data.components.find(c => c.component_id === component_id);

      if (!component) return;

      const updatedComponent = { ...component, drawable, texture: 0 };

      const filteredComponents = data.components.filter(c => c.component_id !== component_id);

      const updatedComponents = [...filteredComponents, updatedComponent];

      const updatedData = { ...data, components: updatedComponents };

      setData(updatedData);

      const updatedComponentSettings = await Nui.post('appearance_change_component', updatedComponent);

      const filteredComponentsSettings = appearanceSettings.components.filter(c => c.component_id !== component_id);

      const updatedComponentsSettings = [...filteredComponentsSettings, updatedComponentSettings];

      const updatedSettings = { ...appearanceSettings, components: updatedComponentsSettings };

      setAppearanceSettings(updatedSettings);
    },
    [data, setData, appearanceSettings, setAppearanceSettings],
  );

  const handleComponentTextureChange = useCallback(
    async (component_id: number, texture: number) => {
      if (!data || !appearanceSettings) return;

      const component = data.components.find(c => c.component_id === component_id);

      if (!component) return;

      const updatedComponent = { ...component, texture };

      const filteredComponents = data.components.filter(c => c.component_id !== component_id);

      const updatedComponents = [...filteredComponents, updatedComponent];

      const updatedData = { ...data, components: updatedComponents };

      setData(updatedData);

      const updatedComponentSettings = await Nui.post('appearance_change_component', updatedComponent);

      const filteredComponentsSettings = appearanceSettings.components.filter(c => c.component_id !== component_id);

      const updatedComponentsSettings = [...filteredComponentsSettings, updatedComponentSettings];

      const updatedSettings = { ...appearanceSettings, components: updatedComponentsSettings };

      setAppearanceSettings(updatedSettings);
    },
    [data, setData, appearanceSettings, setAppearanceSettings],
  );

  const handlePropDrawableChange = useCallback(
    async (prop_id: number, drawable: number) => {
      if (!data || !appearanceSettings) return;

      const prop = data.props.find(p => p.prop_id === prop_id);

      if (!prop) return;

      const updatedProp = { ...prop, drawable, texture: 0 };

      const filteredProps = data.props.filter(p => p.prop_id !== prop_id);

      const updatedProps = [...filteredProps, updatedProp];

      const updatedData = { ...data, props: updatedProps };

      setData(updatedData);

      const updatedPropSettings = await Nui.post('appearance_change_prop', updatedProp);

      const filteredPropsSettings = appearanceSettings.props.filter(c => c.prop_id !== prop_id);

      const updatedPropsSettings = [...filteredPropsSettings, updatedPropSettings];

      const updatedSettings = { ...appearanceSettings, props: updatedPropsSettings };

      setAppearanceSettings(updatedSettings);
    },
    [data, setData, appearanceSettings, setAppearanceSettings],
  );

  const handlePropTextureChange = useCallback(
    async (prop_id: number, texture: number) => {
      if (!data || !appearanceSettings) return;

      const prop = data.props.find(p => p.prop_id === prop_id);

      if (!prop) return;

      const updatedProp = { ...prop, texture };

      const filteredProps = data.props.filter(p => p.prop_id !== prop_id);

      const updatedProps = [...filteredProps, updatedProp];

      const updatedData = { ...data, props: updatedProps };

      setData(updatedData);

      const updatedPropSettings = await Nui.post('appearance_change_prop', updatedProp);

      const filteredPropsSettings = appearanceSettings.props.filter(c => c.prop_id !== prop_id);

      const updatedPropsSettings = [...filteredPropsSettings, updatedPropSettings];

      const updatedSettings = { ...appearanceSettings, props: updatedPropsSettings };

      setAppearanceSettings(updatedSettings);
    },
    [data, setData, appearanceSettings, setAppearanceSettings],
  );

  const isPedFreemodeModel = useMemo(() => {
    if (!data) return;

    return data.model === 'mp_m_freemode_01' || data.model === 'mp_f_freemode_01';
  }, [data]);

  const isPedMale = useMemo(() => {
    if(!data) return;

    if (data.model === 'mp_m_freemode_01') {
      return true;
    }

    return false
  }, [data]);

  const filteredTattooSettings = useMemo<TattoosSettings | undefined>(() => {
    if (!appearanceSettings) return undefined;
    const items = Object.fromEntries(
      Object.entries(appearanceSettings.tattoos.items).map(([zone, tattoos]) => [
        zone,
        tattoos.filter(tattoo => isPedMale ? tattoo.hashMale !== '' : tattoo.hashFemale !== ''),
      ]),
    );
    return { ...appearanceSettings.tattoos, items };
  }, [appearanceSettings, isPedMale]);

  const handleApplyTattoo = useCallback(
    async (tattoo: Tattoo, opacity: number) => {
      if (!data) return;
      tattoo.opacity = opacity;
      const { tattoos } = data;
      const updatedTattoos = JSON.parse(JSON.stringify({ ...tattoos}));
      if (!updatedTattoos[tattoo.zone]) updatedTattoos[tattoo.zone] = [];
      updatedTattoos[tattoo.zone].push(tattoo);
      const applied = await Nui.post('appearance_apply_tattoo', {tattoo, updatedTattoos});
      if(applied) {
        setData({ ...data, tattoos: updatedTattoos });
      }
    },
    [data, setData],
  );

  const handlePreviewTattoo = useCallback(
    (tattoo: Tattoo, opacity: number) => {
      if (!data) return;
      tattoo.opacity = opacity;
      const { tattoos } = data;
      Nui.post('appearance_preview_tattoo', { data: tattoos, tattoo });
    },
    [data],
  );

  const handleDeleteTattoo = useCallback(
    async (tattoo: Tattoo) => {
      if (!data) return;
      const { tattoos } = data;
      const updatedTattoos = {
        ...tattoos,
        [tattoo.zone]: (tattoos[tattoo.zone] ?? []).filter(tattooDelete => tattooDelete.name !== tattoo.name),
      };
      await Nui.post('appearance_delete_tattoo', updatedTattoos);
      setData({ ...data, tattoos: updatedTattoos });
    },
    [data, setData],
  );

  const handleClearTattoos = useCallback(
    async () => {
      if (!data) return;
      const { tattoos } = data;
      const updatedTattoos = { ...tattoos };
      for (var zone in updatedTattoos) {
        if (zone !== "ZONE_HAIR") {
          updatedTattoos[zone] = [];
        }
      }
      await Nui.post('appearance_delete_tattoo', updatedTattoos);
      setData({ ...data, tattoos: updatedTattoos });
    },
    [data, setData],
  );

  useEffect(() => {
    if(!locales) {
      Nui.post('appearance_get_locales').then(result => setLocales(result));
    }

    Nui.onEvent('appearance_display', (data : any) => {
      setDisplay({ appearance: true, asynchronous: data.asynchronous });
    });

    Nui.onEvent('appearance_hide', () => {
      setDisplay({ appearance: false, asynchronous: false });
      setData(APPEARANCE_INITIAL_STATE);
      setStoredData(APPEARANCE_INITIAL_STATE);
      //setAppearanceSettings(SETTINGS_INITIAL_STATE);
      setCamera(CAMERA_INITIAL_STATE);
      setRotate(ROTATE_INITIAL_STATE);
    });

    if (isBrowserPreview) {
      setDisplay({ appearance: true, asynchronous: false });
    }
  }, []);

  const fetchData = useCallback(async () => {
    const result = await Nui.post('appearance_get_data');
    setConfig(result.config);
    setStoredData(result.appearanceData);
    setData(result.appearanceData); 
  }, []);

  const fetchSettings = useCallback(async () => {
    if(appearanceSettings === undefined || appearanceSettings === SETTINGS_INITIAL_STATE) {
      const result = await Nui.post('appearance_get_settings');
      setAppearanceSettings(result.appearanceSettings);
    }
  }, []);

  useEffect(() => {
    if (display.appearance) {
      if(display.asynchronous) {
        (async () => {
          await fetchSettings();
          await fetchData();
        })();
      } else {
        fetchSettings().catch(console.error);
        fetchData().catch(console.error);
      }
    }
  }, [display.appearance]);

  useEffect(() => {
    if (!config) return;

    const availableTabs = [
      config.ped && 'identity',
      isPedFreemodeModel && config.headBlend && 'heritage',
      isPedFreemodeModel && config.faceFeatures && 'face',
      config.headOverlays && 'details',
      config.components && 'clothing',
      config.props && 'accessories',
      isPedFreemodeModel && config.tattoos && 'tattoos',
    ].filter(Boolean) as string[];

    setActiveTab(current => availableTabs.includes(current) ? current : (availableTabs[0] ?? 'identity'));
  }, [config, isPedFreemodeModel]);

  if (!display.appearance || !config || !appearanceSettings || !data || !storedData || !locales) {
    return null;
  }

  const tabs = [
    config.ped && { id: 'identity', label: 'Identidade', icon: <FaUser /> },
    isPedFreemodeModel && config.headBlend && { id: 'heritage', label: 'Herança', icon: <FaDna /> },
    isPedFreemodeModel && config.faceFeatures && { id: 'face', label: 'Rosto', icon: <FaSmile /> },
    config.headOverlays && { id: 'details', label: 'Detalhes', icon: <FaMagic /> },
    config.components && { id: 'clothing', label: 'Roupas', icon: <FaTshirt /> },
    config.props && { id: 'accessories', label: 'Acessórios', icon: <FaHatCowboy /> },
    isPedFreemodeModel && config.tattoos && { id: 'tattoos', label: 'Tatuagens', icon: <FaPaintBrush /> },
  ].filter(Boolean) as { id: string; label: string; icon: JSX.Element }[];

  const activeStep = Math.max(0, tabs.findIndex(tab => tab.id === activeTab));

  return (
    <>
      {wrapperTransition.map(
        ({ item, key, props: style }) =>
          item && (
            <animated.div key={key} style={style}>
              <Wrapper>
                <Container>
                  <PanelHeader>
                    <div className="header-meta">
                      <small>{config.uiEyebrow ?? 'Obscuria'}</small>
                      <span className="step-count">{String(activeStep + 1).padStart(2, '0')} / {String(tabs.length).padStart(2, '0')}</span>
                    </div>
                    <h1>{config.uiTitle ?? 'Personalização de Personagem'}</h1>
                    <p>{config.uiDescription ?? 'Ajuste sua aparência antes de continuar.'}</p>
                  </PanelHeader>
                  <Body>
                    <Navigation>
                      {tabs.map(tab => (
                        <NavButton key={tab.id} active={activeTab === tab.id} onClick={() => setActiveTab(tab.id)} title={tab.label}>
                          {tab.icon}
                          <span>{tab.label}</span>
                        </NavButton>
                      ))}
                    </Navigation>
                    <Content key={activeTab}>
                      {activeTab === 'identity' && config.ped && (
                        <Ped
                          settings={appearanceSettings.ped}
                          storedData={storedData.model}
                          data={data.model}
                          handleModelChange={handleModelChange}
                        />
                      )}
                      {activeTab === 'heritage' && isPedFreemodeModel && config.headBlend && (
                        <HeadBlend
                          settings={appearanceSettings.headBlend}
                          storedData={storedData.headBlend}
                          data={data.headBlend}
                          handleHeadBlendChange={handleHeadBlendChange}
                        />
                      )}
                      {activeTab === 'face' && isPedFreemodeModel && config.faceFeatures && (
                        <FaceFeatures
                          settings={appearanceSettings.faceFeatures}
                          storedData={storedData.faceFeatures}
                          data={data.faceFeatures}
                          handleFaceFeatureChange={handleFaceFeatureChange}
                        />
                      )}
                      {activeTab === 'details' && config.headOverlays && (
                        <HeadOverlays
                          settings={{
                            hair: appearanceSettings.hair,
                            headOverlays: appearanceSettings.headOverlays,
                            eyeColor: appearanceSettings.eyeColor,
                            fade: appearanceSettings.tattoos.items['ZONE_HAIR']
                          }}
                          storedData={{
                            hair: storedData.hair,
                            headOverlays: storedData.headOverlays,
                            eyeColor: storedData.eyeColor,
                            fade: storedData.tattoos?.ZONE_HAIR?.length > 0 ? storedData.tattoos.ZONE_HAIR[0] : null
                          }}
                          data={{
                            hair: data.hair,
                            headOverlays: data.headOverlays,
                            eyeColor: data.eyeColor,
                            fade: data.tattoos?.ZONE_HAIR?.length > 0 ? data.tattoos.ZONE_HAIR[0] : null
                          }}
                          isPedFreemodeModel={isPedFreemodeModel}
                          handleHairChange={handleHairChange}
                          handleHeadOverlayChange={handleHeadOverlayChange}
                          handleEyeColorChange={handleEyeColorChange}
                          handleChangeFade={handleChangeFade}
                          automaticFade={config.automaticFade}
                        />
                      )}
                      {activeTab === 'clothing' && config.components && (
                        <Components
                          settings={appearanceSettings.components}
                          data={data.components}
                          storedData={storedData.components}
                          handleComponentDrawableChange={handleComponentDrawableChange}
                          handleComponentTextureChange={handleComponentTextureChange}
                          componentConfig={config.componentConfig}
                          hasTracker={config.hasTracker}
                          isPedFreemodeModel={isPedFreemodeModel}
                        />
                      )}
                      {activeTab === 'accessories' && config.props && (
                        <Props
                          settings={appearanceSettings.props}
                          data={data.props}
                          storedData={storedData.props}
                          handlePropDrawableChange={handlePropDrawableChange}
                          handlePropTextureChange={handlePropTextureChange}
                          propConfig={config.propConfig}
                        />
                      )}
                      {activeTab === 'tattoos' && isPedFreemodeModel && config.tattoos && filteredTattooSettings && (
                        <Tattoos
                          settings={filteredTattooSettings}
                          data={data.tattoos}
                          storedData={storedData.tattoos}
                          isPedMale={Boolean(isPedMale)}
                          handleApplyTattoo={handleApplyTattoo}
                          handlePreviewTattoo={handlePreviewTattoo}
                          handleDeleteTattoo={handleDeleteTattoo}
                          handleClearTattoos={handleClearTattoos}
                        />
                      )}
                    </Content>
                  </Body>
                  <Options
                    camera={camera}
                    rotate={rotate}
                    clothes={clothes}
                    handleSetClothes={handleSetClothes}
                    handleSetCamera={handleSetCamera}
                    handleTurnAround={handleTurnAround}
                    handleRotateLeft={handleRotateLeft}
                    handleRotateRight={handleRotateRight}
                    handleSave={handleSaveModal}
                    handleExit={handleExitModal}
                    enableExit={config.enableExit}
                  />
                </Container>
              </Wrapper>
            </animated.div>
          ),
      )}
      {saveModalTransition.map(
        ({ item, key, props: style }) =>
          item && (
            <animated.div key={key} style={style}>
              <Modal
                title={locales.modal.save.title}
                description={locales.modal.save.description}
                accept={locales.modal.accept}
                decline={locales.modal.decline}
                handleAccept={() => handleSave(true)}
                handleDecline={() => handleSave(false)}
              />
            </animated.div>
          ),
      )}
      {exitModalTransition.map(
        ({ item, key, props: style }) =>
          item && (
            <animated.div key={key} style={style}>
              <Modal
                title={locales.modal.exit.title}
                description={locales.modal.exit.description}
                accept={locales.modal.accept}
                decline={locales.modal.decline}
                handleAccept={() => handleExit(true)}
                handleDecline={() => handleExit(false)}
              />
            </animated.div>
          ),
      )}
    </>
  );
};

export default Appearance;
