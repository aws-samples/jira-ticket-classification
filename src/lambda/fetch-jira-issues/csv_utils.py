import csv
import io

def create_csv(data, fieldnames=None):
    if not data:
        print("The data list is empty.")
        return None
    
    if fieldnames is None:
        fieldnames = data[0].keys()
    
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()
    for row in data:
        writer.writerow(row)
    
    return output.getvalue()