import pyperclip

def process_simulation_data(data: str):
    data = data[2:].replace('"', '')
    values = data.split(",")
    means = []
    votes = []
    result = ""
    for i in range(0, len(values), 3):
        means.append(values[i + 1])
        votes.append(values[i + 2])
        result += values[i + 1] + "	" + values[i + 2] + "\n"
    print("Average mean: ", sum([float(x) for x in means]) / len(means))
    print("Average votes: ", sum([float(x) for x in votes]) / len(votes))
    
    pyperclip.copy(result)


if __name__ == '__main__':
    data = input("Paste the data here: ")
    process_simulation_data(data)

