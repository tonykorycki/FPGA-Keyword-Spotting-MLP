#!/usr/bin/env python3
"""
FPGA-KWS Full Training Pipeline
This script runs the entire keyword spotting pipeline:
1. Converts raw audio files to processed format
2. Extracts features from the processed audio
3. Trains the model
4. Quantizes the model for FPGA implementation

Usage:
    python run_pipeline.py [--skip_convert] [--skip_features] [--epochs 50] [--batch_size 32]
                          [--hidden_size 64] [--bits 8] [--visualize]
"""
    
import os
import sys
import argparse
import importlib.util
import subprocess
import time

# Path configuration
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PYTHON_DIR = os.path.join(SCRIPT_DIR, "python")
sys.path.append(PYTHON_DIR)

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Run the full KWS training pipeline")
    parser.add_argument("--skip_convert", action="store_true",
                       help="Skip audio conversion step (if already done)")
    parser.add_argument("--skip_features", action="store_true",
                       help="Skip feature extraction step (if already done)")
    parser.add_argument("--epochs", type=int, default=50,
                       help="Number of training epochs")
    parser.add_argument("--batch_size", type=int, default=32,
                       help="Training batch size")
    parser.add_argument("--hidden_size", type=int, default=64,
                       help="Size of hidden layer")
    parser.add_argument("--bits", type=int, default=8,
                       help="Bit precision for quantization")
    parser.add_argument("--visualize", action="store_true",
                       help="Visualize features during extraction")
    return parser.parse_args()

def check_data_exists():
    """Check if raw data exists in preprocessed folders."""
    preprocessed_dir = os.path.join(SCRIPT_DIR, "data", "preprocessed")
    classes = ["start", "silence", "noise"]
    
    for class_name in classes:
        class_dir = os.path.join(preprocessed_dir, class_name)
        if not os.path.exists(class_dir):
            print(f"ERROR: Directory not found: {class_dir}")
            return False
        
        wav_files = [f for f in os.listdir(class_dir) if f.endswith('.wav')]
        if not wav_files:
            print(f"ERROR: No WAV files found in {class_dir}")
            return False
    
    return True

def run_step(step_name, module_name, function_name="main", args=None):
    """Run a pipeline step by importing a module and calling its main function."""
    print(f"\n{'='*80}\n{step_name}\n{'='*80}")
    
    try:
        # Import the module
        spec = importlib.util.spec_from_file_location(
            module_name, 
            os.path.join(PYTHON_DIR, f"{module_name}.py")
        )
        if spec is None or spec.loader is None:
            raise ImportError(f"Cannot load module {module_name} from {os.path.join(PYTHON_DIR, f'{module_name}.py')}")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        
        # Call the main function with args if provided
        main_func = getattr(module, function_name)
        if args:
            main_func(args)
        else:
            main_func()
        
        print(f"\n✓ {step_name} completed successfully!")
        return True
    
    except Exception as e:
        print(f"ERROR in {step_name}: {e}")
        return False

def convert_args_to_namespace(args_dict):
    """Convert a dictionary of args to an argparse.Namespace object."""
    args = argparse.Namespace()
    for key, value in args_dict.items():
        setattr(args, key, value)
    return args

def main():
    start_time = time.time()
    args = parse_args()
    
    # Check for data before starting
    if not args.skip_convert and not check_data_exists():
        print("Please add audio recordings to the data/preprocessed/{start,silence,noise} folders first.")
        sys.exit(1)
    
    # Step 1: Convert audio files
    if not args.skip_convert:
        subprocess.run(["python", os.path.join(PYTHON_DIR, "batch_convert.py")])
    else:
        print("\nSkipping audio conversion step...")
    
    # Step 2: Extract features
    if not args.skip_features:
        feature_args = {"visualize": args.visualize}
        if not run_step("Feature Extraction", "make_features", 
                       args=convert_args_to_namespace(feature_args)):
            sys.exit(1)
    else:
        print("\nSkipping feature extraction step...")
    
    # Step 3: Train model
    train_args = {
        "epochs": args.epochs,
        "batch_size": args.batch_size,
        "hidden_size": args.hidden_size
    }
    if not run_step("Model Training", "train_model", 
                   args=convert_args_to_namespace(train_args)):
        sys.exit(1)
    
    # Step 4: Quantize model
    quantize_args = {
        "model_path": os.path.join(SCRIPT_DIR, "models", "kws_model.h5"),
        "bits": args.bits,
        "output_dir": os.path.join(SCRIPT_DIR, "models")
    }
    if not run_step("Model Quantization", "quantize_model", 
                   args=convert_args_to_namespace(quantize_args)):
        sys.exit(1)
    
    elapsed_time = time.time() - start_time
    print(f"\n{'='*80}")
    print(f"Pipeline completed in {elapsed_time:.2f} seconds!")
    print(f"Model saved to: {os.path.join(SCRIPT_DIR, 'models', 'kws_model.h5')}")
    print(f"Quantized model files saved to: {os.path.join(SCRIPT_DIR, 'models')}")
    print(f"{'='*80}")

if __name__ == "__main__":
    main()