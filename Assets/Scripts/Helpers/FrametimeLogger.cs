using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class FrametimeLogger : MonoBehaviour
{
    public int framesToRecord = 100;//Total frames to log
    private int frameCount = 0;//Counter
    private List<float> frameTimes = new List<float>();//List of recorded frametimes
    [SerializeField]private string fileName = "FrametimeLog.csv";//Output file name

    void Update()
    {
        if (frameCount < framesToRecord)
        {
            float frameTime = Time.deltaTime * 1000f;//Frametime in milliseconds
            frameTimes.Add(frameTime);
            frameCount++;
        }
        else if (frameCount == framesToRecord)
        {
            SaveToCSV();
            frameCount++;//Prevent running again
        }
    }

    void SaveToCSV()
    {
        string folderPath = Application.dataPath + "/FrametimeLogs/";
        Directory.CreateDirectory(folderPath);//Make sure the folder exists

        string fullPath = Path.Combine(folderPath, fileName);

        using (StreamWriter writer = new StreamWriter(fullPath))
        {
            writer.WriteLine("Frame,Frametime(ms)");
            for (int i = 0; i < frameTimes.Count; i++)
            {
                writer.WriteLine($"{i + 1},{frameTimes[i]}");
            }
        }

        Debug.Log($"Frametime log saved to: {fullPath}");
    }
}

