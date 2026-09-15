---Job names must be lower case (top level table key)
---@type table<string, Job>
return {
    ['unemployed'] = {
        label = 'Civilian',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Freelancer',
                payment = 10
            },
        },
    },
    ['police'] = {
        label = 'LSPD',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Officer',
                payment = 75
            },
            [2] = {
                name = 'Sergeant',
                payment = 100
            },
            [3] = {
                name = 'Lieutenant',
                payment = 125
            },
            [4] = {
                name = 'Chief',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['bcso'] = {
        label = 'BCSO',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Officer',
                payment = 75
            },
            [2] = {
                name = 'Sergeant',
                payment = 100
            },
            [3] = {
                name = 'Lieutenant',
                payment = 125
            },
            [4] = {
                name = 'Chief',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['sasp'] = {
        label = 'SASP',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Officer',
                payment = 75
            },
            [2] = {
                name = 'Sergeant',
                payment = 100
            },
            [3] = {
                name = 'Lieutenant',
                payment = 125
            },
            [4] = {
                name = 'Chief',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['ambulance'] = {
        label = 'Médico',
        type = 'ems',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruta',
                payment = 1000
            },
            [1] = {
                name = 'Paramedico',
                payment = 1250
            },
            [2] = {
                name = 'Doutor',
                payment = 1500
            },
            [3] = {
                name = 'Cirurgião',
                payment = 1500
            },
            [4] = {
                name = 'Diretor',
                isboss = true,
                bankAuth = true,
                payment = 1500
            },
        },
    },
    ['realestate'] = {
        label = 'Real Estate',
        type = 'realestate',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'House Sales',
                payment = 75
            },
            [2] = {
                name = 'Business Sales',
                payment = 100
            },
            [3] = {
                name = 'Broker',
                payment = 125
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['taxi'] = {
        label = 'Taxi',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Driver',
                payment = 75
            },
            [2] = {
                name = 'Event Driver',
                payment = 100
            },
            [3] = {
                name = 'Sales',
                payment = 125
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['bus'] = {
        label = 'Bus',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Driver',
                payment = 50
            },
        },
    },
    ['cardealer'] = {
        label = 'Vehicle Dealer',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Showroom Sales',
                payment = 75
            },
            [2] = {
                name = 'Business Sales',
                payment = 100
            },
            [3] = {
                name = 'Finance',
                payment = 125
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['mechanic'] = {
        label = 'Automativa Akuma',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruta',
                payment = 550
            },
            [1] = {
                name = 'Novato',
                payment = 775
            },
            [2] = {
                name = 'Experiente',
                payment = 1100
            },
            [3] = {
                name = 'Supervisor',
                payment = 1125
            },
            [4] = {
                name = 'Dono',
                isboss = true,
                bankAuth = true,
                payment = 1550
            },
        },
    },
    ['judge'] = {
        label = 'Honorary',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Judge',
                payment = 100
            },
        },
    },
    ['lawyer'] = {
        label = 'Law Firm',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Associate',
                payment = 50
            },
        },
    },
    ['reporter'] = {
        label = 'Reporter',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Journalist',
                payment = 50
            },
        },
    },
    ['trucker'] = {
        label = 'Trucker',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Driver',
                payment = 50
            },
        },
    },
    ['tow'] = {
        label = 'Towing',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Driver',
                payment = 50
            },
        },
    },
    ['garbage'] = {
        label = 'Garbage',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Collector',
                payment = 50
            },
        },
    },
    ['vineyard'] = {
        label = 'Vineyard',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Picker',
                payment = 50
            },
        },
    },
    ['hotdog'] = {
        label = 'Hotdog',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Sales',
                payment = 50
            },
        },
    },
    ['vanilla'] = {
        label = 'Vanilla',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Aprendiz', payment = 50 },
            [1] = { name = 'Atendente', payment = 75 },
            [2] = { name = 'Artista', payment = 100 },
            [3] = { name = 'Gerente', isboss = true, payment = 125 },
            [4] = { name = 'Proprietário', isboss = true, bankAuth = true, payment = 150 },
        },
    },
    ['cafebens'] = {
        label = 'Dreamy Coffee',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Aprendiz', payment = 750 },
            [1] = { name = 'Atendente', payment = 875 },
            [2] = { name = 'Barista', payment = 900 },
            [3] = { name = 'Gerente', isboss = true, payment = 1125 },
            [4] = { name = 'Proprietário', isboss = true, bankAuth = true, payment = 1150 },
        },
    },
    ['bahama'] = {
        label = 'Bahama Mamas',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Aprendiz', payment = 50 },
            [1] = { name = 'Atendente', payment = 75 },
            [2] = { name = 'Bartender', payment = 100 },
            [3] = { name = 'Gerente', isboss = true, payment = 125 },
            [4] = { name = 'Proprietário', isboss = true, bankAuth = true, payment = 150 },
        },
    },
    ['club77'] = {
        label = 'Club 77',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Aprendiz', payment = 50 },
            [1] = { name = 'Atendente', payment = 75 },
            [2] = { name = 'Bartender', payment = 100 },
            [3] = { name = 'Gerente', isboss = true, payment = 125 },
            [4] = { name = 'Proprietário', isboss = true, bankAuth = true, payment = 150 },
        },
    },
    ['moomoo'] = {
        label = 'MooMoo Cafe',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Aprendiz', payment = 50 },
            [1] = { name = 'Atendente', payment = 75 },
            [2] = { name = 'Barista', payment = 100 },
            [3] = { name = 'Gerente', isboss = true, payment = 125 },
            [4] = { name = 'Proprietário', isboss = true, bankAuth = true, payment = 150 },
        },
    },
    ['chinese'] = {
        label = 'Chinese Seoul',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Aprendiz', payment = 50 },
            [1] = { name = 'Atendente', payment = 75 },
            [2] = { name = 'Chef', payment = 100 },
            [3] = { name = 'Gerente', isboss = true, payment = 125 },
            [4] = { name = 'Proprietário', isboss = true, bankAuth = true, payment = 150 },
        },
    },
}
