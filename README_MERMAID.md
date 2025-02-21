graph TD
    A[Start] --> B[Set $VerbosePreference = 'Continue']
    B --> C[Import InitializePowerCli.psm1]
    C --> D{try}
    D --> E[Read-YamlConfig<br>Parse YAML from ConfigPath]
    E -->|Success| F[Extract Domain Settings<br>domainName, timeZone, etc.]
    F --> G[Initialize-PowerCLI<br>Connect to vCenter with Credential]
    G --> H[For Each VM in config.vms]
    
    H --> I[Get-TargetObjects<br>Retrieve Host, Datastore, etc.]
    I --> J[Create-CustomizationSpec<br>Set Admin, Domain, Timezone]
    J --> K{Existing Spec?}
    K -->|Yes| L[Remove Existing Spec]
    L --> M[Create New Spec]
    K -->|No| M
    M --> N[Remove-ExistingNicMappings<br>Clear Old NIC Settings]
    N --> O[Add-NicMapping<br>Set Static IP, Subnet, etc.]
    O --> P[Verify-NicMapping<br>Check NIC Count = 1]
    P --> Q[Update-SpecSID<br>Set ChangeSID = true]
    
    Q --> R{VMHost Connected?}
    R -->|Yes| S[New-CustomVM<br>Create VM from Template]
    S --> T{NIC StartConnected?}
    T -->|No| U[Set-NetworkAdapter<br>StartConnected = true]
    T -->|Yes| V[Log VM Deployment Complete]
    U --> V
    R -->|No| W[Log Error & Skip VM]
    
    V --> X{Next VM?}
    W --> X
    X -->|Yes| H
    X -->|No| Y[Log All Deployments Complete]
    Y --> Z[End]
    
    D -->|catch| AA[Log Error & Exit]
    AA --> Z

    subgraph Error Handling
        AA
    end