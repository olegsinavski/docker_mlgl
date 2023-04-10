import lz4
import matplotlib.pyplot as plt
import msgpack_numpy
import numpy as np
import cv2
import pandas as pd
from PIL import Image
from sklearn import datasets
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import seaborn as sns
import torch
import torchvision


def main():
    """
    Just run bunch of things to check it imports fine
    """
    # test lz4
    data = b'Hello World'
    compressed_data = lz4.frame.compress(data)
    decompressed_data = lz4.frame.decompress(compressed_data)
    assert data == decompressed_data

    # test matplotlib
    x = np.linspace(0, 2*np.pi, 100)
    y = np.sin(x)
    plt.plot(x, y)
    plt.title('Sin wave')
    plt.show()

    # test msgpack-numpy
    data = np.random.rand(100, 100)
    packed_data = msgpack_numpy.packb(data)
    unpacked_data = msgpack_numpy.unpackb(packed_data, raw=False)
    assert np.allclose(data, unpacked_data)

    # test numpy
    a = np.array([1, 2, 3])
    b = np.array([4, 5, 6])
    c = np.dot(a, b)
    assert c == 32

    # test opencv
    img = (np.random.rand(100,100, 3) * 255).astype(np.uint8)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    cv2.imshow('Test Image', gray)
    cv2.waitKey(0)
    cv2.destroyAllWindows()

    # test pandas
    data = {'name': ['John', 'Alice', 'Bob'], 'age': [25, 30, 35]}
    df = pd.DataFrame(data)
    assert len(df) == 3

    # test Pillow
    img = Image.open('test_image.png')
    img.show()

    # test scikit-learn
    iris = datasets.load_iris()
    X = iris.data
    y = iris.target
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    clf = svm.SVC(kernel='linear', C=1)
    clf.fit(X_train, y_train)
    y_pred = clf.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    assert acc > 0.8

    # test scipy
    x = np.linspace(0, 2*np.pi, 100)
    y = np.sin(x)
    z = np.cos(x)
    corr = np.corrcoef(y, z)[0, 1]
    assert np.isclose(corr, 0)

    # test seaborn
    tips = sns.load_dataset("tips")
    sns.boxplot(x="day", y="total_bill", data=tips)

    # test torch
    x = torch.randn(10, 5)
    y = torch.randn(10, 2)
    linear = torch.nn.Linear(5, 2)
    pred = linear(x)
    loss_func = torch.nn.MSELoss()
    loss = loss_func(pred, y)
    assert loss > 0

    # test torchvision
    transform = torchvision.transforms.Compose([
        torchvision.transforms.RandomCrop(32, padding=4),
        torchvision.transforms.RandomHorizontalFlip(),
        torchvision.transforms.ToTensor()
    ])
    train_dataset = torchvision.datasets.CIFAR10(root='./data', train=True, download=True, transform=transform)
    assert len(train_dataset) == 50000


if __name__ == '__main__':
    main()
