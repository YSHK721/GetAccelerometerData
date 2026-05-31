#!/bin/zsh

# デバッグ出力を有効化
set -x

# エラーが発生した場合、スクリプトを終了
set -e

echo "==== デバッグ: スクリプト開始 ===="

# スクリプトのある場所を取得して表示
script_dir=$(dirname "$0")
echo "==== デバッグ: スクリプトのディレクトリ: $script_dir ===="
cd "$script_dir"
echo "==== デバッグ: 現在のディレクトリ: $(pwd) ===="

# 設定パラメータ
source_dir="$(pwd)"
output_dir="$(pwd)/MergedFiles"
echo "==== デバッグ: ソースディレクトリ: $source_dir ===="
echo "==== デバッグ: 出力ディレクトリ: $output_dir ===="

# 出力ディレクトリの作成
mkdir -p "$output_dir"
echo "==== デバッグ: 出力ディレクトリを作成しました ===="

# 現在の日時を取得
timestamp=$(date +"%Y%m%d_%H%M%S")
echo "==== デバッグ: タイムスタンプ: $timestamp ===="

# 出力ファイルの作成
output_file="$output_dir/merged_$timestamp.swift"
echo "==== デバッグ: 出力ファイル作成: $output_file ===="

# 単純なfindコマンドを実行（除外フォルダなし）
echo "==== デバッグ: 単純なfindコマンド実行開始 ===="
find "$source_dir" -type f -name "*.swift" -not -path "*/MergedFiles/*" > /tmp/swift_files.txt
find_status=$?
echo "==== デバッグ: findコマンド終了コード: $find_status ===="

# ファイルの行数をカウント
file_count=$(wc -l < /tmp/swift_files.txt | tr -d ' ')
echo "==== デバッグ: 見つかったSwiftファイル数: $file_count ===="

# 一時ファイルの内容を確認（最初の3行）
echo "==== デバッグ: 一時ファイルの内容（最初の3行）: ===="
head -n 3 /tmp/swift_files.txt
echo "==== デバッグ: 一時ファイルの内容確認終了 ===="

if [ "$file_count" -gt 0 ]; then
    echo "==== デバッグ: ファイル処理開始 ===="
    
    processed=0
    while IFS= read -r file; do
        echo "==== デバッグ: 処理中のファイル: $file ===="
        
        if [ -f "$file" ]; then
            echo "Processing: $file"
            {
                echo "// Source: $file"
                echo ""
                cat "$file"
                echo ""
                echo "// End of file: $file"
                echo ""
                echo ""
            } >> "$output_file"
            
            processed=$((processed + 1))
            echo "==== デバッグ: 処理済み: $processed / $file_count ===="
        else
            echo "==== デバッグ: ファイルが存在しません: $file ===="
        fi
    done < /tmp/swift_files.txt
    
    # 出力ファイルのサイズを確認
    file_size=$(wc -c < "$output_file")
    echo "==== デバッグ: 出力ファイルサイズ: $file_size バイト ===="
    
    # 完了メッセージ
    echo "Merge completed: merged_$timestamp.swift has been saved to $output_dir"
    echo "Total files processed: $processed"
else
    echo "No Swift files found in the specified directory."
fi

# 一時ファイルの削除
rm /tmp/swift_files.txt
echo "==== デバッグ: 一時ファイル削除完了 ===="
echo "==== デバッグ: スクリプト終了 ===="