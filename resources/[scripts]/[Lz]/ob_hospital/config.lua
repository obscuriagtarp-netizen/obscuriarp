Config = {}

Config.Debug = false
Config.Job = {
    name = 'ambulance',
    type = 'ems',
    managerGrade = 4,
    editRecordsGrade = 4,
    receptionGrade = 0
}

Config.Management = {
    hireDistance = 5.0,
    initialGrade = 0,
    setPrimaryJobOnHire = true
}

Config.AdminAce = 'obscuria.hospital.admin'
Config.AdminPermissions = { 'admin', 'god' }
Config.HospitalKey = 'pillbox'
Config.InteractionDistance = 2.0
Config.DisplayRenderDistance = 18.0
Config.DisplayRefreshMs = 5000
Config.CallCooldownSeconds = 30
Config.CallRetentionDays = 30

Config.Points = {
    panel = vec3(-1006.81, -409.44, 38.62),
    stash = vec3(309.78, -596.60, 43.29),
    armory = vec3(309.93, -602.94, 43.29),
    display = vec3(-1003.69, -413.68, 38.62),
    triage = vec3(-1006.81, -409.44, 38.62),
    billing = vec3(-1011.97, -412.86, 38.62)
}

Config.Billing = {
    nearbyDistance = 5.0,
    terminalDistance = 3.5,
    invoiceExpiryMinutes = 10,
    maxInvoiceAmount = 1000000,
    renewalCheckMinutes = 10,
    companyBank = {
        provider = 'renewed',
        resource = 'Renewed-Banking',
        account = 'ambulance'
    },
    plan = {
        enabled = true,
        name = 'Plano Obscuria Saúde',
        monthlyPrice = 5000,
        intervalDays = 30
    }
}

Config.Queue = {
    checkInDistance = 3.5,
    ticketPrefix = 'A',
    maxPublicEntries = 3,
    calledDisplaySeconds = 60,
    repeatCooldownSeconds = 5,
    staleMinutes = 180
}

Config.QueueVoice = {
    enabled = true,
    language = 'pt-BR',
    rate = 0.92,
    volume = 1.0
}

Config.AutoAttendant = {
    enabled = true,
    model = 's_m_m_doctor_01',
    coords = vec4(-1030.07, -441.18, 38.62, 27.33),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    treatmentPrice = 2000,
    label = 'Atendente hospitalar'
}

Config.Stash = {
    name = 'ob_hospital_medical_storage',
    label = 'Depósito médico',
    slots = 80,
    weight = 250000,
    owner = false,
    groups = { ambulance = 0 }
}

Config.Armory = {
    name = 'ObscuriaHospitalArmory',
    label = 'Farmácia interna',
    groups = { ambulance = 0 },
    inventory = {
        { name = 'radio', price = 0 },
        { name = 'gauze', price = 0 },
        { name = 'bandage', price = 0 },
        { name = 'painkillers', price = 0 },
        { name = 'firstaid', price = 0 },
        { name = 'medical_kit', price = 0 },
        { name = 'medical_stretcher', price = 0, grade = 1 }
    }
}

Config.PublicShop = {
    { name = 'gauze', label = 'Gaze estéril', price = 120, description = 'Curativo para ferimentos leves.' },
    { name = 'bandage', label = 'Bandagem', price = 180, description = 'Bandagem de uso emergencial.' },
    { name = 'painkillers', label = 'Analgésico', price = 260, description = 'Alívio temporário da dor.' },
    { name = 'firstaid', label = 'Primeiros socorros', price = 850, description = 'Kit completo de primeiros socorros.' },
    { name = 'medical_kit', label = 'Kit médico', price = 1400, description = 'Suprimentos médicos avançados.' }
}

Config.Stretcher = {
    enabled = true,
    item = 'medical_stretcher',
    models = {
        raised = 'strykergurney',
        lowered = 'loweredstrykergurney',
        seated = 'sittingstrykergurney'
    },
    fallbackModel = 'v_med_bed2',
    deployOffset = vec3(0.0, 1.4, -1.0),
    pushOffset = vec3(0.0, 1.25, 0.0),
    pushRotation = vec3(0.0, 0.0, 90.0),
    pushGroundOffset = 0.0,
    pushVerticalStep = 0.04,
    vehicleCollisionDistance = 15.0,
    releaseKey = 'X',
    pushAnimation = {
        dict = 'anim@heists@box_carry@',
        clip = 'idle',
        flag = 49
    },
    patientOffset = vec3(0.0, 0.0, 2.10),
    patientRotation = vec3(0.0, 0.0, 90.0),
    maxPatientDistance = 3.0
}

Config.Treatment = {
    maxDistance = 3.0,
    progressDuration = 6500,
    options = {
        {
            id = 'first_aid',
            item = 'firstaid',
            label = 'Aplicar primeiros socorros',
            description = 'Estabiliza ferimentos e recupera parte da vida.',
            icon = 'kit-medical',
            health = 35,
            heal = 'partial'
        },
        {
            id = 'bandage',
            item = 'bandage',
            label = 'Aplicar bandagem',
            description = 'Trata ferimentos leves e recupera parte da vida.',
            icon = 'bandage',
            health = 20,
            heal = 'partial'
        },
        {
            id = 'painkillers',
            item = 'painkillers',
            label = 'Administrar analgésico',
            description = 'Reduz dor, estresse e recupera um pouco da vida.',
            icon = 'pills',
            health = 5,
            stress = 25
        },
        {
            id = 'medical_kit',
            item = 'medical_kit',
            label = 'Usar kit médico avançado',
            description = 'Trata todos os ferimentos e recupera bastante vida.',
            icon = 'briefcase-medical',
            health = 60,
            heal = 'full'
        },
        {
            id = 'revive',
            item = 'firstaid',
            label = 'Reanimar paciente',
            description = 'Uso exclusivo em pacientes inconscientes.',
            icon = 'heart-pulse',
            revive = true
        }
    }
}

Config.Triage = {
    severities = {
        { value = 'stable', label = 'Estável', color = '#4eb88a' },
        { value = 'observation', label = 'Observação', color = '#d5a85e' },
        { value = 'urgent', label = 'Urgente', color = '#e57b61' },
        { value = 'critical', label = 'Crítico', color = '#e54858' }
    },
    bodyParts = {
        head = 'Cabeça', neck = 'Pescoço', chest = 'Tórax', abdomen = 'Abdômen', pelvis = 'Quadril',
        left_shoulder = 'Ombro esquerdo', right_shoulder = 'Ombro direito',
        left_arm = 'Braço esquerdo', right_arm = 'Braço direito',
        left_hand = 'Mão esquerda', right_hand = 'Mão direita',
        upper_back = 'Costas superiores', lower_back = 'Lombar',
        left_thigh = 'Coxa esquerda', right_thigh = 'Coxa direita',
        left_leg = 'Perna esquerda', right_leg = 'Perna direita',
        left_foot = 'Pé esquerdo', right_foot = 'Pé direito',
        back_head = 'Cabeça posterior', back_neck = 'Nuca', back_pelvis = 'Quadril posterior',
        back_left_shoulder = 'Ombro esquerdo posterior', back_right_shoulder = 'Ombro direito posterior',
        back_left_arm = 'Braço esquerdo posterior', back_right_arm = 'Braço direito posterior',
        back_left_hand = 'Mão esquerda posterior', back_right_hand = 'Mão direita posterior',
        back_left_thigh = 'Coxa esquerda posterior', back_right_thigh = 'Coxa direita posterior',
        back_left_leg = 'Perna esquerda posterior', back_right_leg = 'Perna direita posterior',
        back_left_foot = 'Pé esquerdo posterior', back_right_foot = 'Pé direito posterior'
    }
}

Config.Photos = {
    maxPerRecord = 8,
    maxUrlLength = 600,
    allowedProtocols = { 'https://' }
}

Config.Dispatch = {
    defaultReason = 'Solicitação de atendimento médico',
    expirationMinutes = 15,
    priorities = {
        low = { label = 'Baixa', order = 4 },
        normal = { label = 'Normal', order = 3 },
        urgent = { label = 'Urgente', order = 2 },
        critical = { label = 'Crítica', order = 1 }
    },
    playNativeSound = true
}
