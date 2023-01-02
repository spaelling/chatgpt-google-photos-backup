# Google Photos Backup using chat-gpt

I wanted to back up my Google photos to an Azure Storage account, but this is a tedious process where I have to download all of the files, which Google Photos divides into multiple chunks of zip files. This makes restoring a single file tedious, and I also have to manually upload the zip files to a storage account.

I wanted to see if [chatGPT](https://chat.openai.com/chat) could handle this challenge.

## Infrastructure

First we will need somewhere to run the code. I do not want it running on my laptop, so lets get chatGPT to write a bicep file for us to deploy the necessary infrastructure.

*I need a bicep file that deploys a resource group, a consumption based function app, and a storage account. Finally an instruction that uses az cli to deploy the bicep file.*

The proposed answer was not quite right. It fails to include a scope, ie. the resource group scope is subscription, but the other two resources should be scoped to the resource group and defined as modules.

It also still did not provide a correct command to deploy the bicep file as it still wanted to deploy it to a resource group.

The bicep file was for some weird reason also invalid. It was missing valid resource types.

*I need a bicep file called main.bicep that deploys a resource group, and as modules a consumption based function app and a storage account. Finally an instruction that uses az cli to deploy the bicep file to a subscription in which you provide suggestions for resource naming. Provide code snippets.*

Still no working code produced, so we dumb it down and remove the resource group part. Still not a lot of luck with bicep (it suddenly started providing syntax invalid bicep), so switched to Terraform. It could be that it has not yet sufficient training on bicep. We must remember that the training data ends in 2021.

*I need a Terraform file called main.tf that deploys a consumption based function app and a storage account. The function app is using the nodejs runtime. Location is westeurope. Use parameters for resource names. Finally an example how to deploy the Terraform file in which you provide suggestions for resource naming. Provide code snippets.*

The file produced looked ok. I realized that terraform has a tiny bit of overhead to use, like you need to have the Terraform client installed, and it needs to be initialized, and there is a state to keep track of. As this is a one time deployment, we can just ignore state.

The file did have a few errors, so I tried feeding those back into chatGPT until a working Terraform file was produced.

I accepted that if error output could on its own guide me to how to fix it, then I would not feed it back into chatGPT, ex. it never told me to run `terraform init`, but terraform itself does, so that was ok.
It did take a bit of convincing to make it produce a correct terraform file, especially missing the `azurerm` provider, which I had to be very specific about.

The next issue I encountered, as expected, was the non-unique storage account name. It did try various measures of postfixing the name with a random string, but it kept putting this into the default value which is not allowed. I tried a different approach of asking it to provide random names in `terraform apply`.

I was unable to convince it to do this, but suddenly it did create a terraform file with correct use of a random string. The storage account named generated was not valid as it included a `-`, which it removed after telling it that there is one. It also improved the `resource "random_string" "suffix"` block, which was nice.

At this point we have what seems to be a working terraform file. I do feel that if someone had zero prior knowledge of Terraform, they would have a bad experience.
I still ended up with an unspecified error that chatGPT was unable to solve. I will leave the main.tf as is, and move on to a different approach.

*I need an ARM template file called main.json that deploys a consumption based function app and a storage account. The function app is using the nodejs runtime. Location is westeurope. Use parameters for resource names and postfix them with random strings to make them unique. Finally an example how to deploy the template in which you provide suggestions for resource naming. Provide code snippets.*

It still struggles with naming and continues to suggest `-` in the storage account name. It did take some convincing again to provide the code to postfix a random string to make the storage account name unique. But then this included uppercase letters which chatGPT itself stated could not be included in a valid storage account name.
I finally had to intervene and assist with picking a correct `apiVersion/apiProfile`. It was also missing an app service plan resource, which I had to have it retrofit.

### Summary

At this point I have spent a few hours trying to make chatGPT provide IaC for a very basic setup. I could have written the same myself tens of times in the same time. I do not feel this is especially handy for someone with little to no knowledge of Azure and IaC, as they would struggle a lot with overcoming the small errors in the code chatGPT provides. And even though we often get some decent suggestions for making corrections to the code, it might be difficult for someone with ex. no experience with ARM templates to make the changes and additions to make it work.

## Code

Now we can move on to writing some code for the function app. Here I make the crude assumption that we already know how to run function app code locally. I will try and ask chatGPT to assist with deploying the code later. I also assume basic skills with typescript/node js and running this in a function app.

*I want to write a function app function that copies all the files in my Google Photos. I want to copy them to an Azure storage account called mystorageaccountwvdkjmyi and into a blob container named after the current year and month. function app should run once a month Output as markdown with code snippets in typescript. In the function code you must use a filestream as source.*

I get into the usual struggle with different package versions not quite matching examples. Honestly, this happens all the time when copying code from Stack Overflow, and chatGPT was decent in assisting with changes to the code, just by providing it the errors I get in VS Code.

The first real struggle was with authenticating to Google API. It kept trying to use interfaces that was not exported from the given module. I was using the latest version of each dependency, and it could be a problem yet again with the training for chatGPT stopping in 2021.
It was kind of a one trick pony here and kept regurgitating below even when this does not match all the different interfaces it suggested.

```typescript
// Replace with your own client ID and client secret
clientId: "YOUR_CLIENT_ID",
clientSecret: "YOUR_CLIENT_SECRET",
// Scopes are the permissions that you are requesting
scopes: ["https://www.googleapis.com/auth/photoslibrary.readonly"],
```

So I tried to force it to use a code snippet with the following prompt (after browsing over some official documentation)

*using this snippet*

```typescript
// Create a configuration object that implements the GoogleAuth interface
const auth = new GoogleAuth({
scopes: "https://www.googleapis.com/auth/photoslibrary.readonly",
});
// Create an authentication object using the GoogleAuth constructor
const client = await auth.getClient();

// Use the client object to create a client for the Google Photos API
const photosClient = photos({ version: "v1", auth: client });
```

*complete the original prompt*

After a few attempts, chatGPT always stopped halfway. Some of the code provided looked decent, and other times it was way off again, not using the code snippet provided. Realizing that it is probably too much to take on at once we start over with just solving one of the problems.

It looked like we should use [Application Default Credentials](https://cloud.google.com/nodejs/docs/reference/google-auth-library/latest#application-default-credentials), so we give some hints at that.

*I want to write an async function in typescript that lists all the files in my Google Photos, and then returns a list of filestream to each photo. Use the GOOGLE_APPLICATION_CREDENTIALS environment variable and this snippet for authentication*

```typescript
const auth = new GoogleAuth({
scopes: 'https://www.googleapis.com/auth/photoslibrary.readonl'
});
const client = await auth.getClient();
```

*Output as markdown with code snippets in typescript.*

I got something with only few errors. There was a type mismatch in the function that gets an authenticated client object, and then it kept coming up with code where either the node module did not exist, at least not something I could find at [www.npmjs.com](www.npmjs.com) or anywhere else, or the function it tried to use was not exported from the modules that did exist.

Maybe there is no module for Google Photos specifically, so we try Google Drive again. And to save time, just skip the authentication part as we have that down (but not tested yet).
It actually does look like there is only a Java and PHP client library for [Google Photos API](https://developers.google.com/photos/library/guides/client-libraries)

*I want to write an async function in typescript that lists all the files in my Google Photos, and then returns a list of filestream to each file. I already have a function that returns an authenticated client, so do not write the code for that. Use only RESTful APIs and the axios module.
Output as markdown with code snippets in typescript.*

This did provide a function that looked very much like it would work. Now we are ready to test it out.

At this point I feel like again you would struggle hard if you had little or not developer experience. chatGPT generally understands context, and the history of a conversation, yet it kept suggestion the same errornous code, and if I had little clue on what I was doing I would stand no chance to see through the bullshit and call it on it. I think it is essential that we are critical of the solutions it proposes and look up official documentation ourselves to see if it even makes the slightest sense.
It is fairly good once guide, ex. to use a specific module or package, or if we instruct it like we did here, to use RESTful APIs.

I have also spent many hours, also taking a bit of time writing this up, and also some time just waiting for chatGPT finishing up "typing" out answers. Writing the IaC is something I could do in a few minutes, and DuckDuckGoing how to write the code we wrestled from chatGPT would take less than an hour. So no time saver yet, not even close!



https://developers.google.com/photos/library/guides/about-restful-apis