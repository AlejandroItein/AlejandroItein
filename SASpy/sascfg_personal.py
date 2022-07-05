#import saspy, os
#print(saspy.__file__.replace('__init__.py', 'sascfg_personal.py'))

SAS_config_names=['oda','acuatecontzi','sasdemo','sasviya']
oda = {'java' : 'C:\\java\\bin\\java.exe',
#US Home Region
'iomhost' : ['odaws01-usw2.oda.sas.com','odaws02-usw2.oda.sas.com','odaws03-usw2.oda.sas.com','odaws04-usw2.oda.sas.com'],
#European Home Region
#'iomhost' : ['odaws01-euw1.oda.sas.com','odaws02-euw1.oda.sas.com'],
#Asia Pacific Home Region
#'iomhost' : ['odaws01-apse1.oda.sas.com','odaws02-apse1.oda.sas.com'],
'iomport' : 8591,
'authkey' : 'oda',
'encoding' : 'utf-8'
}

acuatecontzi = {'ip'      : 'sas.macropay.mx',
                'port'    : '443',
                'user'    : 'acuatecontzi',
                'pw'      : '^BpiEP^"U2g9uLdwI0H~',
                'context' : 'SAS Studio compute context',
               }

sasdemo =       {'ip'     : 'sas.macropay.mx',
                'port'    : '443',
                'user'    : 'sasdemo',
                'pw'      : 'M4cR0D3mo',
                'context' : 'SAS Studio compute context',
                }

sasviya =       {'ip'     : 'azureuse011465.my-trials.sas.com',
                'port'    : '443',
                'user'    : 'alejandro.cuatecontzi.itein@outlook.com',
                'pw'      : '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',
                'context' : 'SAS Studio compute context',
                }