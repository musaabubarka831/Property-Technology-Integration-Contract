;; title: Smart Building System Integration and Management
;; version: 1.0.0
;; summary: Smart contract for managing building units, system status, and maintenance scheduling
;; description: This contract provides comprehensive building management capabilities including
;;              unit registration, system monitoring, and automated maintenance workflows

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-UNIT-NOT-FOUND (err u404))
(define-constant ERR-UNIT-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-DATA (err u400))
(define-constant ERR-SYSTEM-NOT-FOUND (err u404))
(define-constant ERR-MAINTENANCE-NOT-FOUND (err u404))
(define-constant ERR-CALCULATION-ERROR (err u500))

;; System type constants
(define-constant SYSTEM-HVAC u1)
(define-constant SYSTEM-LIGHTING u2)
(define-constant SYSTEM-SECURITY u3)
(define-constant SYSTEM-WATER u4)
(define-constant SYSTEM-ELECTRICAL u5)

;; Maintenance status constants
(define-constant MAINTENANCE-SCHEDULED u1)
(define-constant MAINTENANCE-IN-PROGRESS u2)
(define-constant MAINTENANCE-COMPLETED u3)
(define-constant MAINTENANCE-CANCELLED u4)

;; Contract owner and admin management
(define-data-var contract-owner principal tx-sender)
(define-data-var building-admin principal tx-sender)

;; Unit and maintenance counters
(define-data-var unit-counter uint u0)
(define-data-var maintenance-counter uint u0)

;; Building unit registry
(define-map building-units
  { unit-id: uint }
  {
    building-name: (string-ascii 50),
    floor: uint,
    unit-number: uint,
    unit-type: (string-ascii 30),
    owner: principal,
    tenant: (optional principal),
    registration-block: uint,
    active: bool
  }
)

;; System status for each unit
(define-map unit-systems
  { unit-id: uint, system-type: uint }
  {
    status: (string-ascii 20),
    temperature: (optional uint),
    power-consumption: (optional uint),
    last-updated: uint,
    operational: bool
  }
)

;; Building-wide system overview
(define-map building-systems
  { building-name: (string-ascii 50), system-type: uint }
  {
    total-units: uint,
    operational-units: uint,
    average-consumption: uint,
    last-maintenance: uint
  }
)

;; Maintenance scheduling
(define-map maintenance-schedule
  { maintenance-id: uint }
  {
    unit-id: uint,
    system-type: uint,
    scheduled-block: uint,
    description: (string-ascii 200),
    technician: (optional principal),
    status: uint,
    priority: uint,
    estimated-duration: uint
  }
)

;; Unit maintenance history
(define-map unit-maintenance-history
  { unit-id: uint }
  { maintenance-ids: (list 50 uint) }
)

;; Energy consumption tracking
(define-map energy-consumption
  { unit-id: uint, period: uint }
  {
    hvac-consumption: uint,
    lighting-consumption: uint,
    total-consumption: uint,
    timestamp: uint
  }
)

;; Building occupancy tracking
(define-map building-occupancy
  { building-name: (string-ascii 50) }
  {
    total-units: uint,
    occupied-units: uint,
    vacancy-rate: uint,
    last-updated: uint
  }
)

;; Alert system for critical issues
(define-map system-alerts
  { alert-id: uint }
  {
    unit-id: uint,
    system-type: uint,
    severity: uint,
    message: (string-ascii 150),
    timestamp: uint,
    resolved: bool
  }
)

(define-data-var alert-counter uint u0)

;; PUBLIC FUNCTIONS

;; Register a new building unit
(define-public (register-unit (building-name (string-ascii 50)) (floor uint) (unit-number uint) (unit-type (string-ascii 30)))
  (let (
    (current-counter (var-get unit-counter))
    (new-unit-id (+ current-counter u1))
    (caller tx-sender)
  )
    ;; Validate input data
    (asserts! (> (len building-name) u0) ERR-INVALID-DATA)
    (asserts! (> floor u0) ERR-INVALID-DATA)
    (asserts! (> unit-number u0) ERR-INVALID-DATA)
    
    ;; Create new unit entry
    (map-set building-units
      { unit-id: new-unit-id }
      {
        building-name: building-name,
        floor: floor,
        unit-number: unit-number,
        unit-type: unit-type,
        owner: caller,
        tenant: none,
        registration-block: block-height,
        active: true
      }
    )
    
    ;; Initialize unit systems
    (initialize-unit-systems new-unit-id)
    
    ;; Initialize maintenance history
    (map-set unit-maintenance-history
      { unit-id: new-unit-id }
      { maintenance-ids: (list) }
    )
    
    ;; Update building occupancy
    (update-building-occupancy building-name)
    
    ;; Update counter
    (var-set unit-counter new-unit-id)
    
    (ok new-unit-id)
  )
)

;; Update system status
(define-public (update-system-status (unit-id uint) (system-type uint) (status (string-ascii 20)) (temperature (optional uint)) (power-consumption (optional uint)))
  (let (
    (unit (unwrap! (map-get? building-units { unit-id: unit-id }) ERR-UNIT-NOT-FOUND))
  )
    ;; Check authorization (unit owner, tenant, or admin)
    (asserts! (or (is-eq tx-sender (get owner unit))
                  (match (get tenant unit)
                    tenant-principal (is-eq tx-sender tenant-principal)
                    false)
                  (is-eq tx-sender (var-get building-admin))) 
              ERR-NOT-AUTHORIZED)
    
    ;; Validate system type
    (asserts! (and (>= system-type u1) (<= system-type u5)) ERR-INVALID-DATA)
    
    ;; Update system status
    (map-set unit-systems
      { unit-id: unit-id, system-type: system-type }
      {
        status: status,
        temperature: temperature,
        power-consumption: power-consumption,
        last-updated: block-height,
        operational: (not (is-eq status "error"))
      }
    )
    
    ;; Update building-wide system stats
    (update-building-system-stats (get building-name unit) system-type)
    
    ;; Create alert if system error detected
    (if (is-eq status "error")
      (create-system-alert unit-id system-type u3 "System error detected")
      true
    )
    
    (ok true)
  )
)

;; Schedule maintenance
(define-public (schedule-maintenance (unit-id uint) (system-type uint) (scheduled-block uint) (description (string-ascii 200)) (priority uint))
  (let (
    (unit (unwrap! (map-get? building-units { unit-id: unit-id }) ERR-UNIT-NOT-FOUND))
    (current-counter (var-get maintenance-counter))
    (new-maintenance-id (+ current-counter u1))
  )
    ;; Check authorization (unit owner or admin)
    (asserts! (or (is-eq tx-sender (get owner unit))
                  (is-eq tx-sender (var-get building-admin))
                  (is-eq tx-sender (var-get contract-owner))) 
              ERR-NOT-AUTHORIZED)
    
    ;; Validate input
    (asserts! (>= scheduled-block block-height) ERR-INVALID-DATA)
    (asserts! (and (>= priority u1) (<= priority u5)) ERR-INVALID-DATA)
    
    ;; Create maintenance entry
    (map-set maintenance-schedule
      { maintenance-id: new-maintenance-id }
      {
        unit-id: unit-id,
        system-type: system-type,
        scheduled-block: scheduled-block,
        description: description,
        technician: none,
        status: MAINTENANCE-SCHEDULED,
        priority: priority,
        estimated-duration: u4 ;; Default 4 blocks
      }
    )
    
    ;; Update unit maintenance history
    (let (
      (existing-history (default-to { maintenance-ids: (list) } 
                        (map-get? unit-maintenance-history { unit-id: unit-id })))
      (updated-list (unwrap! (as-max-len? 
                            (append (get maintenance-ids existing-history) new-maintenance-id) 
                            u50) 
                    ERR-CALCULATION-ERROR))
    )
      (map-set unit-maintenance-history
        { unit-id: unit-id }
        { maintenance-ids: updated-list }
      )
    )
    
    ;; Update counter
    (var-set maintenance-counter new-maintenance-id)
    
    (ok new-maintenance-id)
  )
)

;; Assign technician to maintenance
(define-public (assign-technician (maintenance-id uint) (technician principal))
  (let (
    (maintenance (unwrap! (map-get? maintenance-schedule { maintenance-id: maintenance-id }) ERR-MAINTENANCE-NOT-FOUND))
  )
    ;; Check if caller is admin
    (asserts! (or (is-eq tx-sender (var-get building-admin))
                  (is-eq tx-sender (var-get contract-owner))) 
              ERR-NOT-AUTHORIZED)
    
    ;; Update maintenance record
    (map-set maintenance-schedule
      { maintenance-id: maintenance-id }
      {
        unit-id: (get unit-id maintenance),
        system-type: (get system-type maintenance),
        scheduled-block: (get scheduled-block maintenance),
        description: (get description maintenance),
        technician: (some technician),
        status: (get status maintenance),
        priority: (get priority maintenance),
        estimated-duration: (get estimated-duration maintenance)
      }
    )
    
    (ok true)
  )
)

;; Complete maintenance
(define-public (complete-maintenance (maintenance-id uint))
  (let (
    (maintenance (unwrap! (map-get? maintenance-schedule { maintenance-id: maintenance-id }) ERR-MAINTENANCE-NOT-FOUND))
  )
    ;; Check if caller is assigned technician or admin
    (asserts! (or (match (get technician maintenance)
                    technician-principal (is-eq tx-sender technician-principal)
                    false)
                  (is-eq tx-sender (var-get building-admin))
                  (is-eq tx-sender (var-get contract-owner))) 
              ERR-NOT-AUTHORIZED)
    
    ;; Update maintenance status to completed
    (map-set maintenance-schedule
      { maintenance-id: maintenance-id }
      {
        unit-id: (get unit-id maintenance),
        system-type: (get system-type maintenance),
        scheduled-block: (get scheduled-block maintenance),
        description: (get description maintenance),
        technician: (get technician maintenance),
        status: MAINTENANCE-COMPLETED,
        priority: (get priority maintenance),
        estimated-duration: (get estimated-duration maintenance)
      }
    )
    
    (ok true)
  )
)

;; Record energy consumption
(define-public (record-energy-consumption (unit-id uint) (period uint) (hvac-consumption uint) (lighting-consumption uint))
  (let (
    (unit (unwrap! (map-get? building-units { unit-id: unit-id }) ERR-UNIT-NOT-FOUND))
    (total-consumption (+ hvac-consumption lighting-consumption))
  )
    ;; Check authorization
    (asserts! (or (is-eq tx-sender (get owner unit))
                  (is-eq tx-sender (var-get building-admin))) 
              ERR-NOT-AUTHORIZED)
    
    ;; Record consumption data
    (map-set energy-consumption
      { unit-id: unit-id, period: period }
      {
        hvac-consumption: hvac-consumption,
        lighting-consumption: lighting-consumption,
        total-consumption: total-consumption,
        timestamp: block-height
      }
    )
    
    (ok total-consumption)
  )
)

;; Set tenant for a unit
(define-public (set-tenant (unit-id uint) (tenant principal))
  (let (
    (unit (unwrap! (map-get? building-units { unit-id: unit-id }) ERR-UNIT-NOT-FOUND))
  )
    ;; Check if caller is unit owner
    (asserts! (is-eq tx-sender (get owner unit)) ERR-NOT-AUTHORIZED)
    
    ;; Update unit with tenant
    (map-set building-units
      { unit-id: unit-id }
      {
        building-name: (get building-name unit),
        floor: (get floor unit),
        unit-number: (get unit-number unit),
        unit-type: (get unit-type unit),
        owner: (get owner unit),
        tenant: (some tenant),
        registration-block: (get registration-block unit),
        active: (get active unit)
      }
    )
    
    ;; Update building occupancy
    (update-building-occupancy (get building-name unit))
    
    (ok true)
  )
)

;; READ-ONLY FUNCTIONS

;; Get unit information
(define-read-only (get-unit-info (unit-id uint))
  (map-get? building-units { unit-id: unit-id })
)

;; Get system status
(define-read-only (get-system-status (unit-id uint) (system-type uint))
  (map-get? unit-systems { unit-id: unit-id, system-type: system-type })
)

;; Get maintenance schedule
(define-read-only (get-maintenance-info (maintenance-id uint))
  (map-get? maintenance-schedule { maintenance-id: maintenance-id })
)

;; Get unit maintenance history
(define-read-only (get-unit-maintenance-history (unit-id uint))
  (map-get? unit-maintenance-history { unit-id: unit-id })
)

;; Get energy consumption data
(define-read-only (get-energy-consumption (unit-id uint) (period uint))
  (map-get? energy-consumption { unit-id: unit-id, period: period })
)

;; Get building occupancy
(define-read-only (get-building-occupancy (building-name (string-ascii 50)))
  (map-get? building-occupancy { building-name: building-name })
)

;; Get building system overview
(define-read-only (get-building-system-overview (building-name (string-ascii 50)) (system-type uint))
  (map-get? building-systems { building-name: building-name, system-type: system-type })
)

;; Get system alert
(define-read-only (get-system-alert (alert-id uint))
  (map-get? system-alerts { alert-id: alert-id })
)

;; Get total unit count
(define-read-only (get-total-unit-count)
  (ok (var-get unit-counter))
)

;; Get contract admin info
(define-read-only (get-admin-info)
  (ok { contract-owner: (var-get contract-owner), building-admin: (var-get building-admin) })
)

;; Check if unit is operational
(define-read-only (is-unit-operational (unit-id uint))
  (let (
    (hvac-status (map-get? unit-systems { unit-id: unit-id, system-type: SYSTEM-HVAC }))
    (lighting-status (map-get? unit-systems { unit-id: unit-id, system-type: SYSTEM-LIGHTING }))
    (security-status (map-get? unit-systems { unit-id: unit-id, system-type: SYSTEM-SECURITY }))
  )
    (ok (and 
         (get operational (unwrap! hvac-status (err false)))
         (get operational (unwrap! lighting-status (err false)))
         (get operational (unwrap! security-status (err false)))))
  )
)

;; PRIVATE FUNCTIONS

;; Initialize all systems for a new unit
(define-private (initialize-unit-systems (unit-id uint))
  (begin
    ;; Initialize HVAC
    (map-set unit-systems
      { unit-id: unit-id, system-type: SYSTEM-HVAC }
      { status: "operational", temperature: (some u22), power-consumption: (some u0), last-updated: block-height, operational: true })
    
    ;; Initialize Lighting
    (map-set unit-systems
      { unit-id: unit-id, system-type: SYSTEM-LIGHTING }
      { status: "operational", temperature: none, power-consumption: (some u0), last-updated: block-height, operational: true })
    
    ;; Initialize Security
    (map-set unit-systems
      { unit-id: unit-id, system-type: SYSTEM-SECURITY }
      { status: "armed", temperature: none, power-consumption: (some u0), last-updated: block-height, operational: true })
    
    ;; Initialize Water
    (map-set unit-systems
      { unit-id: unit-id, system-type: SYSTEM-WATER }
      { status: "operational", temperature: none, power-consumption: none, last-updated: block-height, operational: true })
    
    ;; Initialize Electrical
    (map-set unit-systems
      { unit-id: unit-id, system-type: SYSTEM-ELECTRICAL }
      { status: "operational", temperature: none, power-consumption: (some u0), last-updated: block-height, operational: true })
    
    true
  )
)

;; Update building occupancy statistics
(define-private (update-building-occupancy (building-name (string-ascii 50)))
  (let (
    (current-occupancy (default-to 
                       { total-units: u0, occupied-units: u0, vacancy-rate: u0, last-updated: block-height }
                       (map-get? building-occupancy { building-name: building-name })))
    (new-total (+ (get total-units current-occupancy) u1))
    ;; Assume unit is occupied if it has a tenant or owner activity
    (new-occupied (+ (get occupied-units current-occupancy) u1))
    (new-vacancy-rate (if (> new-total u0) (/ (* (- new-total new-occupied) u100) new-total) u0))
  )
    (map-set building-occupancy
      { building-name: building-name }
      {
        total-units: new-total,
        occupied-units: new-occupied,
        vacancy-rate: new-vacancy-rate,
        last-updated: block-height
      }
    )
    true
  )
)

;; Update building-wide system statistics
(define-private (update-building-system-stats (building-name (string-ascii 50)) (system-type uint))
  (let (
    (current-stats (default-to 
                   { total-units: u0, operational-units: u0, average-consumption: u0, last-maintenance: u0 }
                   (map-get? building-systems { building-name: building-name, system-type: system-type })))
  )
    (map-set building-systems
      { building-name: building-name, system-type: system-type }
      {
        total-units: (+ (get total-units current-stats) u1),
        operational-units: (+ (get operational-units current-stats) u1),
        average-consumption: (get average-consumption current-stats),
        last-maintenance: (get last-maintenance current-stats)
      }
    )
    true
  )
)

;; Create system alert
(define-private (create-system-alert (unit-id uint) (system-type uint) (severity uint) (message (string-ascii 150)))
  (let (
    (current-counter (var-get alert-counter))
    (new-alert-id (+ current-counter u1))
  )
    (map-set system-alerts
      { alert-id: new-alert-id }
      {
        unit-id: unit-id,
        system-type: system-type,
        severity: severity,
        message: message,
        timestamp: block-height,
        resolved: false
      }
    )
    (var-set alert-counter new-alert-id)
    true
  )
)
