import sys

def calculate_fibonacci(n):
    """Calculate the first n Fibonacci numbers."""
    if n <= 0:
        return []
    elif n == 1:
        return [0]
    
    sequence = [0, 1]
    for _ in range(2, n):
        sequence.append(sequence[-1] + sequence[-2])
    return sequence

if __name__ == "__main__":
    # Default to 10 numbers if no argument is provided
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    result = calculate_fibonacci(n)
    print(f"First {n} Fibonacci numbers: {result}")
