import pyperclip

def process_simulation_data(data: str):
    data = data[2:].replace('"', '')
    values = data.split(",")
    result = ""
    for i in range(0, len(values), 5):
        result += values[i + 1] + "	" + values[i + 2] + "	" + values[i + 3] + "	" + values[i + 4] + "\n"
    pyperclip.copy(result)


if __name__ == '__main__':
    data = input("Paste the data here: ")
    process_simulation_data(data)

