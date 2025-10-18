#!/usr/bin/env python3
"""
Keyword Spotting System - Model Training Script
Author: 
Date: October 17, 2025

This script trains a simple MLP model for keyword spotting using
the features extracted by make_features.py.
"""

import os
import argparse
import numpy as np
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.metrics import confusion_matrix, classification_report
import tensorflow as tf
# Import keras directly - this is the recommended way in TF 2.19+
import keras
from keras import layers, models

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Train KWS model")
    parser.add_argument("--features_dir", type=str, default="../data/features",
                       help="Directory containing extracted features")
    parser.add_argument("--output_dir", type=str, default="../models",
                       help="Directory to save trained model")
    parser.add_argument("--epochs", type=int, default=50,
                       help="Number of training epochs")
    parser.add_argument("--batch_size", type=int, default=32,
                       help="Training batch size")
    parser.add_argument("--hidden_size", type=int, default=64,
                       help="Size of hidden layer")
    return parser.parse_args()

def ensure_dir(directory):
    """Create directory if it doesn't exist."""
    if not os.path.exists(directory):
        os.makedirs(directory)

def build_model(input_shape, hidden_size=64):
    """Build a simple MLP model for keyword spotting."""
    model = models.Sequential([
        layers.Flatten(input_shape=input_shape),
        layers.Dense(hidden_size, activation='relu'),
        layers.Dropout(0.3),
        layers.Dense(2, activation='softmax')  # 2 classes: keyword and noise
    ])
    
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    return model

def plot_training_history(history):
    """Plot training history."""
    plt.figure(figsize=(12, 4))
    
    # Plot training & validation accuracy
    plt.subplot(1, 2, 1)
    plt.plot(history.history['accuracy'])
    plt.plot(history.history['val_accuracy'])
    plt.title('Model accuracy')
    plt.ylabel('Accuracy')
    plt.xlabel('Epoch')
    plt.legend(['Train', 'Validation'], loc='lower right')
    
    # Plot training & validation loss
    plt.subplot(1, 2, 2)
    plt.plot(history.history['loss'])
    plt.plot(history.history['val_loss'])
    plt.title('Model loss')
    plt.ylabel('Loss')
    plt.xlabel('Epoch')
    plt.legend(['Train', 'Validation'], loc='upper right')
    
    plt.tight_layout()
    plt.show()

def plot_confusion_matrix(y_true, y_pred):
    """Plot confusion matrix."""
    cm = confusion_matrix(y_true, y_pred)
    
    plt.figure(figsize=(8, 6))
    plt.imshow(cm, interpolation='nearest', cmap='Blues')
    plt.title('Confusion matrix')
    plt.colorbar()
    
    classes = ['Noise', 'Keyword']
    tick_marks = np.arange(len(classes))
    plt.xticks(tick_marks, classes, rotation=45)
    plt.yticks(tick_marks, classes)
    
    # Label the plot
    fmt = 'd'
    thresh = cm.max() / 2.
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            plt.text(j, i, format(cm[i, j], fmt),
                     ha="center", va="center",
                     color="white" if cm[i, j] > thresh else "black")
    
    plt.tight_layout()
    plt.ylabel('True label')
    plt.xlabel('Predicted label')
    plt.show()

def main():
    args = parse_args()
    
    # Create output directory
    ensure_dir(args.output_dir)
    
    # Load features and labels
    features = np.load(os.path.join(args.features_dir, "features.npy"))
    labels = np.load(os.path.join(args.features_dir, "labels.npy"))
    
    print(f"Loaded features with shape {features.shape}")
    print(f"Loaded labels with shape {labels.shape}")
    
    # Split data into train and test sets
    X_train, X_test, y_train, y_test = train_test_split(
        features, labels, test_size=0.2, random_state=42, stratify=labels
    )
    
    print(f"Training set: {X_train.shape[0]} samples")
    print(f"Test set: {X_test.shape[0]} samples")
    
    # Build model
    model = build_model(X_train.shape[1:], hidden_size=args.hidden_size)
    model.summary()
    
    # Train model
    history = model.fit(
        X_train, y_train,
        epochs=args.epochs,
        batch_size=args.batch_size,
        validation_split=0.2,
        verbose="1"
    )
    
    # Evaluate model
    test_loss, test_acc = model.evaluate(X_test, y_test)
    print(f"Test accuracy: {test_acc:.4f}")
    
    # Make predictions
    y_pred = np.argmax(model.predict(X_test), axis=-1)
    
    # Print classification report
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, target_names=['Noise', 'Keyword']))
    
    # Plot training history
    plot_training_history(history)
    
    # Plot confusion matrix
    plot_confusion_matrix(y_test, y_pred)
    
    # Save model
    model_file = os.path.join(args.output_dir, "kws_model.h5")
    model.save(model_file)
    
    # Save model architecture as JSON
    model_json = model.to_json()
    with open(os.path.join(args.output_dir, "kws_model.json"), "w") as json_file:
        json_file.write(model_json)
    
    print(f"\nModel saved to {model_file}")

if __name__ == "__main__":
    main()