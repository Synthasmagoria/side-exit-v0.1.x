how am i gonna loop this shit?
LoadSound - converts all frames to 32bit up front even if the wav file is 8bit or 16bit
more memory usage, less complexity and realtime overhead
i think it does this with `ma_convert_frames`

then LoadAudioBuffer is called.
it callocs the Raylib AudioBuffer object and the audio frame buffer
it does the latter by getting the size using the following math:
`size_in_frames * channels * ma_get_bytes_per_sample(format)`

then `ma_data_converter_config_init` and `ma_data_converter_init` again because it needs to convert frames again?????
`AUDIO.System.device` holds the device that says everything about the audio that is being played
i think everything is mixed down to fit the format of the device at some point
either on load: like with `LoadSound`
or while streaming: the others
because there is only one raylib device i cant just loop it directly in the main audio loading callback.
what does it even look like though? where is it?

the device is initted in `InitAudioDevice` (predictably)
`#define AUDIO_DEVICE_SAMPLE_RATE 0`
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
this means that the device default sample rate is chosen
does this mean that a varying amount of conversion happens? whatever...

all mixing happens in the main device callback `OnSendAudioDataToDevice`
in order to loop sounds. maybe i can somehow set loop points at the beginning and end
i can see that there's a looping attribute in `rAudioStream` that gets checked here
`LoadAudioBuffer` will set this attribute to false
and `LoadSoundFromWave` which is called by `LoadSound` calls this function
