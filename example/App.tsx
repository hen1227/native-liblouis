import React, {useEffect, useMemo, useState} from 'react';
import {Platform, StyleSheet, Text, TextInput, View, Pressable, ScrollView, Linking} from 'react-native';
import NativeLiblouisModule from 'native-liblouis';

const TABLES = [
    'en-ueb-g1.ctb',
    'en-ueb-g2.ctb'
];

const ensureUnicodePrefix = (t: string) =>
    t.startsWith('unicode.dis') ? t : `unicode.dis,${t}`;

export default function App(): React.JSX.Element {
    const [rawTable, setRawTable] = useState<string>('en-ueb-g1.ctb');
    const [inputText, setInputText] = useState<string>('');
    const [isInitialized, setIsInitialized] = useState<boolean>(
        NativeLiblouisModule.lou_isInitialized()
    );

    // true = text -> braille, false = braille -> text
    const [textToAsciiMode, setTextToAsciiMode] = useState(true);

    const selectedTable = ensureUnicodePrefix(rawTable);

    useEffect(() => {
        if (Platform.OS === 'web' && NativeLiblouisModule.lou_initialize) {
            NativeLiblouisModule.lou_initialize().finally(() => {
                setIsInitialized(NativeLiblouisModule.lou_isInitialized());
            });
        } else {
            // For native platforms, we assume initialization is done in the native module
            setIsInitialized(true);
        }
    }, []);

    const outText = useMemo(() => {
        if (!isInitialized) return 'Liblouis is initializing…';
        try {
            return textToAsciiMode
                ? NativeLiblouisModule.lou_translateString(inputText, selectedTable)
                : NativeLiblouisModule.lou_backTranslateString(inputText, selectedTable);
        } catch (e: any) {
            return `Translation error: ${e?.message ?? String(e)}`;
        }
    }, [inputText, selectedTable, isInitialized, textToAsciiMode]);


    const onSwapMode = () => {
        setInputText(outText);
        setTextToAsciiMode(prev => !prev);
    };

    return (
        <View style={styles.screen}>
            <View style={styles.card}>
                <Text style={styles.title}>native-liblouis Demo</Text>
                <Text style={styles.subtitle}>Pick a table • Translates live to Braille ASCII</Text>

                <ScrollView
                    horizontal
                    showsHorizontalScrollIndicator={false}
                    contentContainerStyle={styles.chipsRow}
                >
                    {TABLES.map((t) => {
                        const isActive = rawTable === t;
                        return (
                            <Pressable
                                key={t}
                                onPress={() => setRawTable(t)}
                                style={({pressed}) => [
                                    styles.chip,
                                    isActive && styles.chipActive,
                                    pressed && styles.chipPressed,
                                ]}
                            >
                                <Text style={[styles.chipText, isActive && styles.chipTextActive]}>
                                    {t.replace('.ctb', '')}
                                </Text>
                            </Pressable>
                        );
                    })}
                </ScrollView>

                <TextInput
                    style={styles.input}
                    placeholder={textToAsciiMode ? 'Type text to convert to Braille ASCII' : 'Type Braille dots to convert to text'}
                    placeholderTextColor="#8b8b8b"
                    onChangeText={setInputText}
                    value={inputText}
                    autoCapitalize="none"
                    autoCorrect={false}
                    keyboardType="default"
                />

                <View style={styles.metaRow}>
                    <Text style={styles.metaLabel}>Table:</Text>
                    <Text style={styles.metaValue}>{selectedTable}</Text>
                </View>

                <Text style={styles.outputLabel}>
                    {textToAsciiMode ? 'Braille ASCII:' : 'Plain text:'}
                </Text>
                <Text selectable style={styles.outputBox}>
                    {outText}
                </Text>

                <View style={styles.footerRow}>
                    <Pressable onPress={onSwapMode}
                               style={({pressed}) => [styles.button, pressed && styles.buttonPressed]}>
                        <Text
                            style={styles.clearBtnText}>{textToAsciiMode ? 'Switch to <- Text' : 'Switch to -> Braille'}</Text>
                    </Pressable>
                    <Text style={styles.status}>
                        {isInitialized ? 'Ready' : 'Initializing…'}
                    </Text>
                </View>

                {/* Credits */}
                <View style={styles.credits}>
                    <Text style={styles.creditText}>
                        Source code on{' '}
                        <Text style={styles.creditLink}
                              onPress={() => Linking.openURL('https://github.com/hen1227/native-liblouis')}>
                            GitHub
                        </Text>
                    </Text>
                    <Text style={styles.creditText}>
                        Built by{' '}
                        <Text style={styles.creditLink} onPress={() => Linking.openURL('https://henhen1227.com')}>
                            Henry Abrahamsen
                        </Text>
                        {" "}
                        <Text style={styles.dot}>•</Text>
                        {" "}
                        (<Text style={styles.creditLink}
                               onPress={() => Linking.openURL('https://funding.henhen1227.com#native-liblouis')}>
                        Support me
                    </Text>)
                    </Text>
                    <Text style={styles.creditText}>
                        Translation powered by{' '}
                        <Text style={styles.creditLink} onPress={() => Linking.openURL('https://liblouis.io')}>
                            liblouis.io
                        </Text>
                    </Text>
                </View>
            </View>
        </View>
    );
}

const mono = Platform.select({ios: 'Menlo', android: 'monospace', default: 'monospace'});

// All styles pretty much from ChatGPT.
const styles = StyleSheet.create({
    screen: {
        flex: 1,
        paddingHorizontal: 16,
        paddingVertical: 24,
        backgroundColor: '#0b0b0f',
        alignItems: 'center',
        justifyContent: 'center',
    },
    card: {
        width: '100%',
        maxWidth: 520,
        backgroundColor: '#10121a',
        borderRadius: 16,
        padding: 16,
        borderWidth: 1,
        borderColor: '#1f2230',
    },
    title: {
        fontSize: 20,
        fontWeight: '700',
        color: '#e7e9ee',
    },
    subtitle: {
        marginTop: 4,
        color: '#a6adbb',
    },
    chipsRow: {
        gap: 8,
        paddingVertical: 12,
    },
    chip: {
        paddingHorizontal: 12,
        paddingVertical: 8,
        borderRadius: 999,
        borderWidth: 1,
        borderColor: '#2a2f42',
        backgroundColor: '#141726',
    },
    chipActive: {
        backgroundColor: '#2a335a',
        borderColor: '#4453a8',
    },
    chipPressed: {
        opacity: 0.9,
        transform: [{scale: 0.98}],
    },
    chipText: {
        color: '#c9cfdb',
        fontSize: 14,
    },
    chipTextActive: {
        color: '#ffffff',
        fontWeight: '600',
    },
    input: {
        height: 44,
        borderRadius: 10,
        borderWidth: 1,
        borderColor: '#2a2f42',
        backgroundColor: '#121524',
        color: '#e7e9ee',
        paddingHorizontal: 12,
        marginTop: 8,
    },
    metaRow: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 6,
        marginTop: 10,
    },
    metaLabel: {color: '#8b93a7'},
    metaValue: {color: '#c9cfdb', fontFamily: mono},
    outputLabel: {
        marginTop: 12,
        marginBottom: 6,
        color: '#8b93a7',
    },
    outputBox: {
        minHeight: 80,
        borderRadius: 10,
        borderWidth: 1,
        borderColor: '#2a2f42',
        backgroundColor: '#0e1120',
        color: '#e7e9ee',
        padding: 12,
        fontSize: 16,
        lineHeight: 22,
        fontFamily: mono,
    },
    footerRow: {
        marginTop: 12,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
    },
    button: {
        paddingHorizontal: 14,
        paddingVertical: 10,
        borderRadius: 8,
        backgroundColor: '#1a1f34',
        borderWidth: 1,
        borderColor: '#2a2f42',
    },
    buttonPressed: {
        opacity: 0.9,
        transform: [{scale: 0.98}],
    },
    clearBtnText: {color: '#d8def0', fontWeight: '600'},
    status: {color: '#8b93a7'},
    dot: {
        color: '#8b93a7',
        fontSize: 14,
    },
    credits: {
        marginTop: 14,
        borderTopWidth: 1,
        borderTopColor: '#1f2230',
        paddingTop: 10,
    },
    creditText: {
        color: '#8b93a7',
        fontSize: 13,
        marginBottom: 4,
    },
    creditLink: {
        color: '#4da3ff',
        textDecorationLine: 'underline',
    },
});
