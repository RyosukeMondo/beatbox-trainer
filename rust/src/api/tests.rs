use super::*;

#[test]
fn test_greet() {
    let result = greet("World".to_string()).unwrap();
    assert_eq!(result, "Hello, World! Flutter Rust Bridge is working.");
}

#[test]
fn test_get_version() {
    let result = get_version().unwrap();
    assert_eq!(result, "0.1.0");
}
