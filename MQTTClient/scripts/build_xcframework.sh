#!/bin/bash
set -e

usage() { echo "Usage: $0 -v <version> -s <URL from s3>, For example: $0 -v 0.15.7 -s s3://aws.com/artifacts" 1>&2; exit 1; }


while getopts ":v:s:" o; do
    case "${o}" in
        v)
            version=${OPTARG}
            ;;
        s)
            aws=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${version}" || -z "${aws}"]; then
    usage
fi

OUTPUTDIR=.tmp/archive
rm -Rf $OUTPUTDIR
mkdir -p $OUTPUTDIR/Debug
GIT_COMMIT=${version}
AWS=${aws}
    
FRAMEWORK_NAME="MQTTClient"
SCHEME="MQTTClientiOS"
xcodebuild archive -scheme $SCHEME -archivePath $OUTPUTDIR/$FRAMEWORK_NAME-iphoneos.xcarchive -sdk iphoneos SKIP_INSTALL=NO
xcodebuild archive -scheme $SCHEME -archivePath $OUTPUTDIR/$FRAMEWORK_NAME-iphonesimulator.xcarchive -sdk iphonesimulator SKIP_INSTALL=NO
xcodebuild -create-xcframework -framework $OUTPUTDIR/$FRAMEWORK_NAME-iphonesimulator.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework -framework $OUTPUTDIR/$FRAMEWORK_NAME-iphoneos.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework -output $OUTPUTDIR/$FRAMEWORK_NAME.xcframework

xcodebuild archive -scheme $SCHEME -archivePath $OUTPUTDIR/Debug/$FRAMEWORK_NAME-iphoneos.xcarchive -sdk iphoneos -configuration Debug SKIP_INSTALL=NO
xcodebuild archive -scheme $SCHEME -archivePath $OUTPUTDIR/Debug/$FRAMEWORK_NAME-iphonesimulator.xcarchive -sdk iphonesimulator -configuration Debug SKIP_INSTALL=NO
xcodebuild -create-xcframework -framework $OUTPUTDIR/Debug/$FRAMEWORK_NAME-iphonesimulator.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework -framework $OUTPUTDIR/Debug/$FRAMEWORK_NAME-iphoneos.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework -output $OUTPUTDIR/Debug/$FRAMEWORK_NAME.xcframework

cd $OUTPUTDIR
zip -r $FRAMEWORK_NAME-$GIT_COMMIT.xcframework.zip $FRAMEWORK_NAME.xcframework
aws s3 cp $FRAMEWORK_NAME-$GIT_COMMIT.xcframework.zip $AWS
cd -

cd $OUTPUTDIR/Debug
zip -r $FRAMEWORK_NAME-$GIT_COMMIT-Debug.xcframework.zip $FRAMEWORK_NAME.xcframework
aws s3 cp $FRAMEWORK_NAME-$GIT_COMMIT-Debug.xcframework.zip $AWS
cd -
