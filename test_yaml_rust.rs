use std::fs;
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: {} <yaml-file>", args[0]);
        std::process::exit(1);
    }
    
    let input = match fs::read_to_string(&args[1]) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Failed to read file: {}", e);
            std::process::exit(1);
        }
    };
    
    match yaml_rust::YamlLoader::load_from_str(&input) {
        Ok(_) => std::process::exit(0),
        Err(_) => std::process::exit(1),
    }
}