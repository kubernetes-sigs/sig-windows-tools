package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"

	"github.com/golang/glog"
	"k8s.io/api/admission/v1beta1"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
)

var (
	runtimeScheme = runtime.NewScheme()
	codecs        = serializer.NewCodecFactory(runtimeScheme)
	deserializer  = codecs.UniversalDeserializer()
)

type WebhookServer struct {
	server *http.Server
}

// Webhook Server parameters
type WhSvrParameters struct {
	port     int    // webhook server port
	certFile string // path to the x509 certificate for https
	keyFile  string // path to the x509 private key matching `CertFile`
}

type patchOperation struct {
	Op    string      `json:"op"`
	Path  string      `json:"path"`
	Value interface{} `json:"value,omitempty"`
}

const (
	lcowRuntimeClassPatch string = `[
		 {"op":"add","path":"/spec/runtimeClassName","value":"lcow"}
	]`

	wcowRuntimeClassPatch string = `[
		 {"op":"add","path":"/spec/runtimeClassName","value":"wcow"}
	]`

	lcowSandboxPlatformPatch string = `[		
		{"op":"add","path":"/metadata/labels","value":{"sandbox-platform": "linux-amd64"}}
	]`

	wcowSandboxPlatformPatch string = `[
		 {"op":"add","path":"/metadata/labels","value":{"sandbox-platform": "windows-amd64"}}
	]`

	replaceSelectorPatch string = `[
		 {"op":"replace","path":"/spec/nodeSelector/beta.kubernetes.io~1os","value": "windows"}
	]`
)

func handlePatch(object interface{}) ([]byte, error) {
	switch object.(type) {
	case *corev1.Pod:
		var pod *corev1.Pod
		pod = object.(*corev1.Pod)
		_, ok := pod.Spec.NodeSelector["beta.kubernetes.io/os"]
		if ok == false {
			glog.Infof("OS node selector is not present, so add Linux")
			return []byte(`[{"op":"add","path":"/spec/nodeSelector","value":{"beta.kubernetes.io/os": "linux"}}]`), nil
		}
	}
	return []byte(`[]`), nil
}

func unmarshalObject(req *v1beta1.AdmissionRequest) (interface{}, error) {

	var object interface{}

	switch req.Kind.Kind {
	case "Pod":
		var pod corev1.Pod
		if err := json.Unmarshal(req.Object.Raw, &pod); err != nil {
			glog.Errorf("Could not unmarshal raw object: %v", err)
			return object, err
		}
		object = &pod
		glog.Infof("AdmissionReview for Kind=%v, Namespace=%v Name=%v (%v) UID=%v patchOperation=%v UserInfo=%v", req.Kind, req.Namespace, req.Name, pod.Name, req.UID, req.Operation, req.UserInfo)

	case "Deployment":
		var deployment appsv1.Deployment
		if err := json.Unmarshal(req.Object.Raw, &deployment); err != nil {
			glog.Errorf("Could not unmarshal raw object: %v", err)
			return object, err
		}
		object = &deployment
		glog.Infof("AdmissionReview for Kind=%v, Namespace=%v Name=%v (%v) UID=%v patchOperation=%v UserInfo=%v", req.Kind, req.Namespace, req.Name, deployment.Name, req.UID, req.Operation, req.UserInfo)

	case "ReplicaSet":
		var replicaSet appsv1.ReplicaSet
		if err := json.Unmarshal(req.Object.Raw, &replicaSet); err != nil {
			glog.Errorf("Could not unmarshal raw object: %v", err)
			return object, err
		}
		object = &replicaSet
		glog.Infof("AdmissionReview for Kind=%v, Namespace=%v Name=%v (%v) UID=%v patchOperation=%v UserInfo=%v", req.Kind, req.Namespace, req.Name, replicaSet.Name, req.UID, req.Operation, req.UserInfo)

	case "StatefulSet":
		var stateFulSet appsv1.StatefulSet
		if err := json.Unmarshal(req.Object.Raw, &stateFulSet); err != nil {
			glog.Errorf("Could not unmarshal raw object: %v", err)
			return object, err
		}
		object = &stateFulSet
		glog.Infof("AdmissionReview for Kind=%v, Namespace=%v Name=%v (%v) UID=%v patchOperation=%v UserInfo=%v", req.Kind, req.Namespace, req.Name, stateFulSet.Name, req.UID, req.Operation, req.UserInfo)
	}

	return object, nil
}

// main mutation process
func (whsvr *WebhookServer) mutate(ar *v1beta1.AdmissionReview) *v1beta1.AdmissionResponse {
	req := ar.Request

	if object, err := unmarshalObject(req); err == nil {
		switch object.(type) {
		default:
			// TODO : test this negative case
			// If User has configured the webhook for not implemented object then don't apply any patch
			reviewResponse := v1beta1.AdmissionResponse{}
			reviewResponse.Allowed = true
			reviewResponse.Patch = []byte(`[]`)
			pt := v1beta1.PatchTypeJSONPatch
			reviewResponse.PatchType = &pt

			return &reviewResponse

		case *corev1.Pod:
			var pod *corev1.Pod
			pod = object.(*corev1.Pod)
			patchBytes, err := handlePatch(pod)
			glog.Infof("AdmissionResponse: patch=%v\n", string(patchBytes))
			if err != nil {
				return &v1beta1.AdmissionResponse{
					Result: &metav1.Status{
						Message: err.Error(),
					},
				}
			} else {
				reviewResponse := v1beta1.AdmissionResponse{}
				reviewResponse.Allowed = true
				reviewResponse.Patch = patchBytes
				pt := v1beta1.PatchTypeJSONPatch
				reviewResponse.PatchType = &pt

				return &reviewResponse
			}
		case *appsv1.Deployment:
			var deployment *appsv1.Deployment
			deployment = object.(*appsv1.Deployment)
			patchBytes, err := handlePatch(deployment)
			glog.Infof("AdmissionResponse: patch=%v\n", string(patchBytes))
			if err != nil {
				return &v1beta1.AdmissionResponse{
					Result: &metav1.Status{
						Message: err.Error(),
					},
				}
			} else {
				reviewResponse := v1beta1.AdmissionResponse{}
				reviewResponse.Allowed = true
				reviewResponse.Patch = patchBytes
				pt := v1beta1.PatchTypeJSONPatch
				reviewResponse.PatchType = &pt

				return &reviewResponse
			}

		case *appsv1.ReplicaSet:
			var replicaSet *appsv1.ReplicaSet
			replicaSet = object.(*appsv1.ReplicaSet)
			patchBytes, err := handlePatch(replicaSet)
			glog.Infof("AdmissionResponse: patch=%v\n", string(patchBytes))
			if err != nil {
				return &v1beta1.AdmissionResponse{
					Result: &metav1.Status{
						Message: err.Error(),
					},
				}
			} else {
				reviewResponse := v1beta1.AdmissionResponse{}
				reviewResponse.Allowed = true
				reviewResponse.Patch = patchBytes
				pt := v1beta1.PatchTypeJSONPatch
				reviewResponse.PatchType = &pt

				return &reviewResponse
			}

		case *appsv1.StatefulSet:
			var stateFulSet *appsv1.StatefulSet
			stateFulSet = object.(*appsv1.StatefulSet)
			patchBytes, err := handlePatch(stateFulSet)
			glog.Infof("AdmissionResponse: patch=%v\n", string(patchBytes))
			if err != nil {
				return &v1beta1.AdmissionResponse{
					Result: &metav1.Status{
						Message: err.Error(),
					},
				}
			} else {
				reviewResponse := v1beta1.AdmissionResponse{}
				reviewResponse.Allowed = true
				reviewResponse.Patch = patchBytes
				pt := v1beta1.PatchTypeJSONPatch
				reviewResponse.PatchType = &pt

				return &reviewResponse
			}
		}
	} else {
		return &v1beta1.AdmissionResponse{
			Result: &metav1.Status{
				Message: err.Error(),
			},
		}
	}

	return &v1beta1.AdmissionResponse{
		Result: &metav1.Status{
			Message: "tmp",
		},
	}

}

// Serve method for webhook server
func (whsvr *WebhookServer) serve(w http.ResponseWriter, r *http.Request) {
	var body []byte
	if r.Body != nil {
		if data, err := ioutil.ReadAll(r.Body); err == nil {
			body = data
		}
	}
	if len(body) == 0 {
		glog.Error("empty body")
		http.Error(w, "empty body", http.StatusBadRequest)
		return
	}

	// verify the content type is accurate
	contentType := r.Header.Get("Content-Type")
	if contentType != "application/json" {
		glog.Errorf("Content-Type=%s, expect application/json", contentType)
		http.Error(w, "invalid Content-Type, expect `application/json`", http.StatusUnsupportedMediaType)
		return
	}

	var admissionResponse *v1beta1.AdmissionResponse
	ar := v1beta1.AdmissionReview{}
	if _, _, err := deserializer.Decode(body, nil, &ar); err != nil {
		glog.Errorf("Can't decode body: %v", err)
		admissionResponse = &v1beta1.AdmissionResponse{
			Result: &metav1.Status{
				Message: err.Error(),
			},
		}
	} else {
		admissionResponse = whsvr.mutate(&ar)
	}

	admissionReview := v1beta1.AdmissionReview{}
	if admissionResponse != nil {
		admissionReview.Response = admissionResponse
		if ar.Request != nil {
			admissionReview.Response.UID = ar.Request.UID
		}
	}

	resp, err := json.Marshal(admissionReview)

	if err != nil {
		glog.Errorf("Can't encode response: %v", err)
		http.Error(w, fmt.Sprintf("could not encode response: %v", err), http.StatusInternalServerError)
	}
	glog.Infof("Ready to write reponse ...")
	if _, err := w.Write(resp); err != nil {
		glog.Errorf("Can't write response: %v", err)
		http.Error(w, fmt.Sprintf("could not write response: %v", err), http.StatusInternalServerError)
	}
}
