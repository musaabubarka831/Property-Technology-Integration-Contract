;; title: IoT Device Coordination and Data Analytics
;; version: 1.0.0
;; summary: Smart contract for managing IoT devices, sensor data collection, and analytics
;; description: This contract provides a comprehensive system for IoT device registration,
;;              sensor data management, and real-time analytics capabilities

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-DEVICE-NOT-FOUND (err u404))
(define-constant ERR-DEVICE-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-DATA (err u400))
(define-constant ERR-NO-DATA (err u404))
(define-constant ERR-CALCULATION-ERROR (err u500))

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Device counter for unique device IDs
(define-data-var device-counter uint u0)

;; Data structures for device information
(define-map devices
  { device-id: uint }
  {
    owner: principal,
    device-name: (string-ascii 50),
    device-type: (string-ascii 30),
    registration-block: uint,
    active: bool
  }
)

;; Map principal to device IDs they own
(define-map principal-devices
  { owner: principal }
  { device-ids: (list 100 uint) }
)

;; Sensor data storage
(define-map sensor-data
  { device-id: uint, data-id: uint }
  {
    value: uint,
    timestamp: uint,
    data-type: (string-ascii 20)
  }
)

;; Data counter per device
(define-map device-data-counter
  { device-id: uint }
  { count: uint }
)

;; Analytics cache for performance
(define-map analytics-cache
  { device-id: uint }
  {
    total-readings: uint,
    sum-value: uint,
    min-value: uint,
    max-value: uint,
    last-updated: uint
  }
)

;; Device status tracking
(define-map device-status
  { device-id: uint }
  {
    online: bool,
    last-ping: uint,
    battery-level: uint
  }
)

;; PUBLIC FUNCTIONS

;; Register a new IoT device
(define-public (register-device (device-name (string-ascii 50)) (device-type (string-ascii 30)))
  (let (
    (current-counter (var-get device-counter))
    (new-device-id (+ current-counter u1))
    (caller tx-sender)
  )
    ;; Check if device name is not empty
    (asserts! (> (len device-name) u0) ERR-INVALID-DATA)
    
    ;; Create new device entry
    (map-set devices
      { device-id: new-device-id }
      {
        owner: caller,
        device-name: device-name,
        device-type: device-type,
        registration-block: block-height,
        active: true
      }
    )
    
    ;; Initialize device data counter
    (map-set device-data-counter
      { device-id: new-device-id }
      { count: u0 }
    )
    
    ;; Initialize device status
    (map-set device-status
      { device-id: new-device-id }
      {
        online: true,
        last-ping: block-height,
        battery-level: u100
      }
    )
    
    ;; Update principal devices list
    (let (
      (existing-devices (default-to { device-ids: (list) } 
                       (map-get? principal-devices { owner: caller })))
      (updated-list (unwrap! (as-max-len? 
                            (append (get device-ids existing-devices) new-device-id) 
                            u100) 
                    ERR-CALCULATION-ERROR))
    )
      (map-set principal-devices
        { owner: caller }
        { device-ids: updated-list }
      )
    )
    
    ;; Update counter
    (var-set device-counter new-device-id)
    
    (ok new-device-id)
  )
)

;; Submit sensor data
(define-public (submit-sensor-data (device-id uint) (value uint) (data-type (string-ascii 20)))
  (let (
    (device (unwrap! (map-get? devices { device-id: device-id }) ERR-DEVICE-NOT-FOUND))
    (data-counter (unwrap! (map-get? device-data-counter { device-id: device-id }) ERR-DEVICE-NOT-FOUND))
    (current-count (get count data-counter))
    (new-count (+ current-count u1))
  )
    ;; Check if caller is device owner
    (asserts! (is-eq tx-sender (get owner device)) ERR-NOT-AUTHORIZED)
    
    ;; Check if device is active
    (asserts! (get active device) ERR-DEVICE-NOT-FOUND)
    
    ;; Store sensor data
    (map-set sensor-data
      { device-id: device-id, data-id: new-count }
      {
        value: value,
        timestamp: block-height,
        data-type: data-type
      }
    )
    
    ;; Update data counter
    (map-set device-data-counter
      { device-id: device-id }
      { count: new-count }
    )
    
    ;; Update analytics cache
    (update-analytics-cache device-id value)
    
    ;; Update device status
    (update-device-ping device-id)
    
    (ok new-count)
  )
)

;; Update device status (ping)
(define-public (update-device-status (device-id uint) (battery-level uint))
  (let (
    (device (unwrap! (map-get? devices { device-id: device-id }) ERR-DEVICE-NOT-FOUND))
  )
    ;; Check if caller is device owner
    (asserts! (is-eq tx-sender (get owner device)) ERR-NOT-AUTHORIZED)
    
    ;; Validate battery level
    (asserts! (<= battery-level u100) ERR-INVALID-DATA)
    
    ;; Update device status
    (map-set device-status
      { device-id: device-id }
      {
        online: true,
        last-ping: block-height,
        battery-level: battery-level
      }
    )
    
    (ok true)
  )
)

;; Deactivate a device
(define-public (deactivate-device (device-id uint))
  (let (
    (device (unwrap! (map-get? devices { device-id: device-id }) ERR-DEVICE-NOT-FOUND))
  )
    ;; Check authorization (device owner or contract owner)
    (asserts! (or (is-eq tx-sender (get owner device))
                  (is-eq tx-sender (var-get contract-owner))) 
              ERR-NOT-AUTHORIZED)
    
    ;; Update device status
    (map-set devices
      { device-id: device-id }
      {
        owner: (get owner device),
        device-name: (get device-name device),
        device-type: (get device-type device),
        registration-block: (get registration-block device),
        active: false
      }
    )
    
    ;; Mark device as offline
    (match (map-get? device-status { device-id: device-id })
      status (map-set device-status
               { device-id: device-id }
               {
                 online: false,
                 last-ping: (get last-ping status),
                 battery-level: (get battery-level status)
               })
      true
    )
    
    (ok true)
  )
)

;; Transfer device ownership
(define-public (transfer-device (device-id uint) (new-owner principal))
  (let (
    (device (unwrap! (map-get? devices { device-id: device-id }) ERR-DEVICE-NOT-FOUND))
  )
    ;; Check if caller is current owner
    (asserts! (is-eq tx-sender (get owner device)) ERR-NOT-AUTHORIZED)
    
    ;; Update device owner
    (map-set devices
      { device-id: device-id }
      {
        owner: new-owner,
        device-name: (get device-name device),
        device-type: (get device-type device),
        registration-block: (get registration-block device),
        active: (get active device)
      }
    )
    
    (ok true)
  )
)

;; READ-ONLY FUNCTIONS

;; Get device information
(define-read-only (get-device-info (device-id uint))
  (map-get? devices { device-id: device-id })
)

;; Get device status
(define-read-only (get-device-status (device-id uint))
  (map-get? device-status { device-id: device-id })
)

;; Get sensor data
(define-read-only (get-sensor-data (device-id uint) (data-id uint))
  (map-get? sensor-data { device-id: device-id, data-id: data-id })
)

;; Get devices owned by principal
(define-read-only (get-principal-devices (owner principal))
  (map-get? principal-devices { owner: owner })
)

;; Get device data count
(define-read-only (get-data-count (device-id uint))
  (map-get? device-data-counter { device-id: device-id })
)

;; Get analytics data
(define-read-only (get-analytics (device-id uint))
  (map-get? analytics-cache { device-id: device-id })
)

;; Calculate average sensor value
(define-read-only (get-average-value (device-id uint))
  (match (map-get? analytics-cache { device-id: device-id })
    analytics (if (> (get total-readings analytics) u0)
                (ok (/ (get sum-value analytics) (get total-readings analytics)))
                ERR-NO-DATA)
    ERR-DEVICE-NOT-FOUND
  )
)

;; Get min/max values
(define-read-only (get-min-max-values (device-id uint))
  (match (map-get? analytics-cache { device-id: device-id })
    analytics (ok { 
                min-value: (get min-value analytics), 
                max-value: (get max-value analytics) 
              })
    ERR-DEVICE-NOT-FOUND
  )
)

;; Get total device count
(define-read-only (get-total-device-count)
  (ok (var-get device-counter))
)

;; Check if device is online (based on last ping)
(define-read-only (is-device-online (device-id uint))
  (match (map-get? device-status { device-id: device-id })
    status (let (
             (time-since-ping (- block-height (get last-ping status)))
           )
           (ok (and (get online status) (< time-since-ping u100))))
    ERR-DEVICE-NOT-FOUND
  )
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; PRIVATE FUNCTIONS

;; Update analytics cache with new data
(define-private (update-analytics-cache (device-id uint) (new-value uint))
  (let (
    (current-analytics (default-to 
                       { total-readings: u0, sum-value: u0, min-value: new-value, max-value: new-value, last-updated: block-height }
                       (map-get? analytics-cache { device-id: device-id })))
    (new-total (+ (get total-readings current-analytics) u1))
    (new-sum (+ (get sum-value current-analytics) new-value))
    (new-min (if (< new-value (get min-value current-analytics)) 
               new-value 
               (get min-value current-analytics)))
    (new-max (if (> new-value (get max-value current-analytics)) 
               new-value 
               (get max-value current-analytics)))
  )
    (map-set analytics-cache
      { device-id: device-id }
      {
        total-readings: new-total,
        sum-value: new-sum,
        min-value: new-min,
        max-value: new-max,
        last-updated: block-height
      }
    )
    true
  )
)

;; Update device ping timestamp
(define-private (update-device-ping (device-id uint))
  (match (map-get? device-status { device-id: device-id })
    status (begin
             (map-set device-status
               { device-id: device-id }
               {
                 online: true,
                 last-ping: block-height,
                 battery-level: (get battery-level status)
               })
             true)
    false
  )
)
