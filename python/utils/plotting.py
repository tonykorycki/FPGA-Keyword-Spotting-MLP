import matplotlib.pyplot as plt
import numpy as np


def plot_history(history):
    plt.figure(figsize=(12, 4))
    plt.subplot(1, 2, 1)
    plt.plot(history.history["accuracy"], label="Train")
    plt.plot(history.history["val_accuracy"], label="Val")
    plt.title("Accuracy")
    plt.legend()
    plt.subplot(1, 2, 2)
    plt.plot(history.history["loss"], label="Train")
    plt.plot(history.history["val_loss"], label="Val")
    plt.title("Loss")
    plt.legend()
    plt.tight_layout()
    plt.show()


def plot_confusion_rect(y_true_actual, y_pred, true_label_names, pred_label_names):
    """Rectangular confusion matrix: rows = actual input types, cols = predicted."""
    n_true, n_pred = len(true_label_names), len(pred_label_names)
    cm = np.zeros((n_true, n_pred), dtype=np.int32)
    for t, p in zip(y_true_actual, y_pred):
        cm[t, p] += 1

    plt.figure(figsize=(7, 5))
    plt.imshow(cm, interpolation="nearest", cmap="Blues", aspect="auto")
    plt.title("Confusion Matrix (Actual vs Predicted)")
    plt.colorbar()
    plt.yticks(np.arange(n_true), true_label_names)
    plt.xticks(np.arange(n_pred), pred_label_names, rotation=45)
    thresh = cm.max() / 2 if cm.max() > 0 else 0.5
    for i in range(n_true):
        for j in range(n_pred):
            plt.text(j, i, str(cm[i, j]), ha="center", va="center",
                     color="white" if cm[i, j] > thresh else "black")
    plt.xlabel("Predicted")
    plt.ylabel("Actual")
    plt.tight_layout()
    plt.show()

def visualize_audio(audio_data):
    """Visualize the recorded audio waveform."""
    audio_array = np.frombuffer(audio_data, dtype=np.int16)
    plt.figure(figsize=(10, 4))
    plt.plot(audio_array)
    plt.title("Recorded Audio Waveform")
    plt.xlabel("Sample")
    plt.ylabel("Amplitude")
    plt.tight_layout()
    plt.show()