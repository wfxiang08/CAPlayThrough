#include "CAPlayThrough.h"
#include "SMPlayThrough.h"


#pragma mark - CAPlayThroughHost Methods

CAPlayThroughHost::CAPlayThroughHost(AudioDeviceID input, AudioDeviceID output):
	mPlayThrough(NULL) {
	CreatePlayThrough(input, output);
}

CAPlayThroughHost::~CAPlayThroughHost() {
	DeletePlayThrough();
}

void CAPlayThroughHost::CreatePlayThrough(AudioDeviceID input, AudioDeviceID output) {
	mPlayThrough = new CAPlayThrough(input, output);
    
    // 重建Queue
    StreamListenerQueue = dispatch_queue_create("com.CAPlayThough.StreamListenerQueue", DISPATCH_QUEUE_SERIAL);
	AddDeviceListeners(input);
}

void CAPlayThroughHost::DeletePlayThrough() {
	if(mPlayThrough) {
		mPlayThrough->Stop();
		RemoveDeviceListeners(mPlayThrough->GetInputDeviceID());
        dispatch_release(StreamListenerQueue);
        StreamListenerQueue = NULL;
		delete mPlayThrough;
		mPlayThrough = NULL;
	}
}

void CAPlayThroughHost::ResetPlayThrough () {
	
	AudioDeviceID input = mPlayThrough->GetInputDeviceID();
	AudioDeviceID output = mPlayThrough->GetOutputDeviceID();

	DeletePlayThrough();
	CreatePlayThrough(input, output);
	mPlayThrough->Start();
}

bool CAPlayThroughHost::PlayThroughExists() {
	return (mPlayThrough != NULL) ? true : false;
}

OSStatus CAPlayThroughHost::Start() {
	if (mPlayThrough) return mPlayThrough->Start();
	return noErr;
}

OSStatus CAPlayThroughHost::Stop() {
	if (mPlayThrough) return mPlayThrough->Stop();
	return noErr;
}

Boolean	CAPlayThroughHost::IsRunning() {
	if (mPlayThrough) return mPlayThrough->IsRunning();
	return noErr;
}

void CAPlayThroughHost::AddDeviceListeners(AudioDeviceID input) {
    // creating the block here allows us access to the this pointer so we can call Reset when required
    AudioObjectPropertyListenerBlock listenerBlock = ^(UInt32 inNumberAddresses,
                                                       const AudioObjectPropertyAddress inAddresses[]) {

        ResetPlayThrough();
        
    };
    
    // need to retain the listener block so that we can remove it later
    StreamListenerBlock = Block_copy(listenerBlock);
    
    AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyStreams,
                                              kAudioDevicePropertyScopeInput,
                                              kAudioObjectPropertyElementMaster };
    
    // StreamListenerBlock is called whenever the sample rate changes (as well as other format characteristics of the device)
	UInt32 propSize;
	OSStatus err = AudioObjectGetPropertyDataSize(input, &theAddress, 0, NULL, &propSize);
    if (err) fprintf(stderr, "Error %ld returned from AudioObjectGetPropertyDataSize\n", (long)err);
    
	if(!err) {
    
		AudioStreamID *streams = (AudioStreamID*)malloc(propSize);	
		err = AudioObjectGetPropertyData(input, &theAddress, 0, NULL, &propSize, streams);
        if (err) fprintf(stderr, "Error %ld returned from AudioObjectGetPropertyData\n", (long)err);
        		
		if(!err) {
			UInt32 numStreams = propSize / sizeof(AudioStreamID);
			
            for(UInt32 i=0; i < numStreams; i++) {
				UInt32 isInput;
				propSize = sizeof(UInt32);
                theAddress.mSelector = kAudioStreamPropertyDirection;
                theAddress.mScope = kAudioObjectPropertyScopeGlobal;
				
                err = AudioObjectGetPropertyData(streams[i], &theAddress, 0, NULL, &propSize, &isInput);
                if (err) fprintf(stderr, "Error %ld returned from AudioObjectGetPropertyData\n", (long)err);

                if(!err && isInput) {
                    theAddress.mSelector = kAudioStreamPropertyPhysicalFormat;
                    
                    err = AudioObjectAddPropertyListenerBlock(streams[i], &theAddress, StreamListenerQueue, StreamListenerBlock);
					//err = AudioObjectAddPropertyListener(streams[i], &theAddress, StreamListener, this);
                    if (err) fprintf(stderr, "Error %ld returned from AudioObjectAddPropertyListenerBlock\n", (long)err);	
                }
            }
        }
        
        if (NULL != streams) free(streams);
    }
}

void CAPlayThroughHost::RemoveDeviceListeners(AudioDeviceID input) {
    AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyStreams,
                                              kAudioDevicePropertyScopeInput,
                                              kAudioObjectPropertyElementMaster };
                                              
	UInt32 propSize;
    OSStatus err = AudioObjectGetPropertyDataSize(input, &theAddress, 0, NULL, &propSize);
    if (err) fprintf(stderr, "Error %ld returned from AudioObjectGetPropertyDataSize\n", (long)err);

	if(!err) {
    
		AudioStreamID *streams = (AudioStreamID*)malloc(propSize);
        err = AudioObjectGetPropertyData(input, &theAddress, 0, NULL, &propSize, streams);
        if (err) fprintf(stderr, "Error %ld returned from AudioObjectGetPropertyData\n", (long)err);
        		
        if(!err) {
			UInt32 numStreams = propSize / sizeof(AudioStreamID);
			
            for(UInt32 i=0; i < numStreams; i++) {
				UInt32 isInput;
				propSize = sizeof(UInt32);
                theAddress.mSelector = kAudioStreamPropertyDirection;
                theAddress.mScope = kAudioObjectPropertyScopeGlobal;
                
                err = AudioObjectGetPropertyData(streams[i], &theAddress, 0, NULL, &propSize, &isInput);
                if (err) fprintf(stderr, "Error %ld returned from AudioObjectGetPropertyData\n", (long)err);

				if(!err && isInput) {
                    theAddress.mSelector = kAudioStreamPropertyPhysicalFormat;
                    
                    err = AudioObjectRemovePropertyListenerBlock(streams[i], &theAddress, StreamListenerQueue, StreamListenerBlock);
                    //err = AudioObjectRemovePropertyListener(streams[i], &theAddress, StreamListener, this);
                    if (err) fprintf(stderr, "Error %ld returned from AudioObjectRemovePropertyListenerBlock\n", (long)err);
                    Block_release(StreamListenerBlock);
                }
			}
		}
        
        if (NULL != streams) free(streams);
	}
}
