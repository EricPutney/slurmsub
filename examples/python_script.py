import sys

def main(arg1, arg2):
    print(f"Argument 1: {arg1}")
    print(f"Argument 2: {arg2}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python example_script.py <arg1> <arg2>")
        sys.exit(1)
    
    arg1 = sys.argv[1]
    arg2 = sys.argv[2]
    
    main(arg1, arg2)
