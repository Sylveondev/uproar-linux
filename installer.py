import tkinter as tk

def quitbutton_click():
    root.destroy()

def nextAbutton_click():
    root.quit()

root = tk.Tk()

root.title("Install Uproar")
#root.geometry("600x400")

label = tk.Label(root, text="Welcome to the Uproar installer. This tool will install Uproar Linux on your device. To continue, click next.", font=("Arial", 16), wraplength=500, justify="left")
# Create a Button widget
quitbutton = tk.Button(root, text="Quit", command=quitbutton_click)
nextbutton = tk.Button(root, text="Continue", command=nextAbutton_click)

label.pack(pady=5) # Add some vertical padding
nextbutton.pack(padx=5, pady=5)
quitbutton.pack(padx=5, pady=5)

root.mainloop()