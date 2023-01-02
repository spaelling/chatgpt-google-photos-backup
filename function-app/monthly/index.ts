import { AzureFunction, Context } from "@azure/functions";

import { Compute, GoogleAuth } from "google-auth-library";
import { JSONClient } from "google-auth-library/build/src/auth/googleauth";

import axios from "axios";

// Replace 'https://www.googleapis.com/auth/photoslibrary.readonly' with the appropriate scope for your application
const SCOPES = ["https://www.googleapis.com/auth/photoslibrary.readonly"];

// Use the GOOGLE_APPLICATION_CREDENTIALS environment variable to authenticate the client
async function getAuthenticatedClient(): Promise<JSONClient | Compute> {
  const auth = new GoogleAuth({
    scopes: SCOPES,
  });
  return auth.getClient();
}

// List all the files in your Google Photos and return a list of file streams for each photo
async function listPhotos(authClient: any) {
  try {
    // Get list of files in Google Photos
    const response = await axios.get(
      "https://photoslibrary.googleapis.com/v1/mediaItems",
      {
        headers: {
          Authorization: `Bearer ${authClient.credentials.access_token}`,
        },
      }
    );
    const files = response.data.mediaItems;

    // Get filestream for each file
    const fileStreams: any[] = [];
    for (const file of files) {
      const fileResponse = await axios.get(
        `https://photoslibrary.googleapis.com/v1/mediaItems/${file.id}`,
        {
          headers: {
            Authorization: `Bearer ${authClient.credentials.access_token}`,
            "Content-Type": "application/octet-stream",
          },
          responseType: "stream",
        }
      );
      fileStreams.push(fileResponse.data);
    }

    return fileStreams;
  } catch (error) {
    console.error(error);
  }
}

const timerTrigger: AzureFunction = async function (
  context: Context,
  myTimer: any
): Promise<void> {
  const client = await getAuthenticatedClient();
  const photos = await listPhotos(client);
};

export default timerTrigger;
