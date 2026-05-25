use regex::Regex;

#[derive(Debug)]
struct GpsTracking {
    prn: u32,
    el: u32,
    az: u32,
    ss: u32,
}

#[derive(Debug)]
struct GpsNotTracking {
    prn: u32,
    el: u32,
    az: u32,
}

#[derive(Debug)]
enum HealthState {
    Ok,
    Fail,
    Unknown,
}

impl HealthState {
    fn from_str(state: &str) -> Self {
        match state {
            "OK" => HealthState::Ok,
            "FAIL" => HealthState::Fail,
            _ => HealthState::Unknown,
        }
    }
}

#[derive(Debug)]
struct HealthMonitor {
    self_test: HealthState,
    int_pwr: HealthState,
    oven_pwr: HealthState,
    ocxo: HealthState,
    efc: HealthState,
    gps_rcv: HealthState,
}

#[derive(Debug)]
enum SmartClockMode {
    LockedToGps,
    Recovery,
    Holdover,
    PowerUp,
    Unknown,
}

impl SmartClockMode {
    fn from_str(mode: &str) -> Self {
        match mode {
            "Locked to GPS" => SmartClockMode::LockedToGps,
            "Recovery" => SmartClockMode::Recovery,
            "Holdover" => SmartClockMode::Holdover,
            "Power-up" => SmartClockMode::PowerUp,
            _ => SmartClockMode::Unknown,
        }
    }
}

fn main() {
    let input = r#"
scpi > :SYSTEM:STATUS?
------------------------------- Receiver Status -------------------------------
SYNCHRONIZATION ............................................. [ Outputs Valid ]
SmartClock Mode ___________________________   Reference Outputs _______________
   Recovery                                   1PPS TI +8.0 ns relative to GPS
>> Locked to GPS                              TFOM     3             FFOM     0
   Holdover                                   HOLD THR 1.000 us
   Power-up                                   Holdover Uncertainty ____________
                                              Predict  12.7 us/initial 24 hrs
                                                
ACQUISITION ................................................ [ GPS 1PPS Valid ]
Tracking: 7 ____   Not Tracking: 1 ________   Time ____________________________
PRN  El  Az   SS   PRN  El  Az                UTC      03:13:42     08 Jun 2005
  5  62  95  167   *28  10 274                GPS 1PPS Synchronized to UTC
 11  17  54   18                              ANT DLY  0 ns
 12  31 163   80                              Position ________________________
 18  35 255  107                              MODE     Hold
 20  36  50  116                              
 25  59 206  141                              LAT      N  37:22:30.277
 29  61 332  138                              LON      W 122:05:34.816
                                              HGT               +43.51 m  (MSL)
ELEV MASK 10 deg   *attempting to track       
HEALTH MONITOR ......................................................... [ OK ]
Self Test: OK    Int Pwr: OK   Oven Pwr: OK   OCXO: OK   EFC: OK   GPS Rcv: OK 
scpi >
"#;

    // Extract SmartClock Mode
    let mode_re = Regex::new(r">>\s*(Locked to GPS|Recovery|Holdover|Power-up)").unwrap();
    let smartclock_mode = if let Some(captures) = mode_re.captures(input) {
        SmartClockMode::from_str(&captures[1])
    } else {
        SmartClockMode::Unknown
    };
    println!("SmartClock Mode: {:?}", smartclock_mode);

    // Extract GPS tracking PRNs
    let tracking_re = Regex::new(r"(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+").unwrap();
    let mut tracking_prns: Vec<GpsTracking> = Vec::new();
    for captures in tracking_re.captures_iter(input) {
        let prn = captures[1].parse::<u32>().unwrap();
        let el = captures[2].parse::<u32>().unwrap();
        let az = captures[3].parse::<u32>().unwrap();
        let ss = captures[4].parse::<u32>().unwrap();
        tracking_prns.push(GpsTracking { prn, el, az, ss });
    }

    // Extract GPS not tracking PRNs
    let not_tracking_re = Regex::new(r"\*\d+\s+(\d+)\s+(\d+)\s+(\d+)").unwrap();
    let mut not_tracking_prns: Vec<GpsNotTracking> = Vec::new();
    for captures in not_tracking_re.captures_iter(input) {
        let prn = captures[1].parse::<u32>().unwrap();
        let el = captures[2].parse::<u32>().unwrap();
        let az = captures[3].parse::<u32>().unwrap();
        not_tracking_prns.push(GpsNotTracking { prn, el, az });
    }

    // Extract Health Monitor states
    let health_monitor_re = Regex::new(
        r"Self Test:\s+(\w+)\s+Int Pwr:\s+(\w+)\s+Oven Pwr:\s+(\w+)\s+OCXO:\s+(\w+)\s+EFC:\s+(\w+)\s+GPS Rcv:\s+(\w+)",
    )
    .unwrap();
    let health_monitor = if let Some(captures) = health_monitor_re.captures(input) {
        HealthMonitor {
            self_test: HealthState::from_str(&captures[1]),
            int_pwr: HealthState::from_str(&captures[2]),
            oven_pwr: HealthState::from_str(&captures[3]),
            ocxo: HealthState::from_str(&captures[4]),
            efc: HealthState::from_str(&captures[5]),
            gps_rcv: HealthState::from_str(&captures[6]),
        }
    } else {
        HealthMonitor {
            self_test: HealthState::Unknown,
            int_pwr: HealthState::Unknown,
            oven_pwr: HealthState::Unknown,
            ocxo: HealthState::Unknown,
            efc: HealthState::Unknown,
            gps_rcv: HealthState::Unknown,
        }
    };

    // Output parsed results
    println!("Tracking PRNs: {:?}", tracking_prns);
    println!("Not Tracking PRNs: {:?}", not_tracking_prns);
    println!("Health Monitor: {:?}", health_monitor);
}
